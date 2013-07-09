#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	Common super-class for controller and subscriber
#
###############################################################################
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the Free
#   Software Foundation; either version 2 of the License, or (at your option)
#   any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
#   more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#   For more information visit www.meteorserver.org
#
###############################################################################

package Meteor::Connection;
###############################################################################
# Configuration
###############################################################################
	
	use strict;
	
	use Errno qw(EAGAIN);
	
	our $MAX_READ_SIZE=8192;
	our $CONNECTION_WRITE_TIMEOUT=120;
	
	our @Connections=();

###############################################################################
# Class methods
###############################################################################
sub addAllHandleBits {
	my $class=shift;
	
	my $rVecRef=shift;
	my $wVecRef=shift;
	my $eVecRef=shift;
	
	my @cons=@Connections;
	map {$_->addHandleBits($rVecRef,$wVecRef,$eVecRef) if(defined($_)) } @cons;
}

sub checkAllHandleBits {
	my $class=shift;
	
	my $rVec=shift;
	my $wVec=shift;
	my $eVec=shift;
	
	my @cons=@Connections;
	map {$_->checkHandleBits($rVec,$wVec,$eVec) if(defined($_)) } @cons;
}

sub connectionCount {
	scalar(@Connections);
}

sub closeAllConnections {
	my @cons=@Connections;
	
	map { $_->close(); } @cons;
}

###############################################################################
# Factory methods
###############################################################################
sub new {
	#
	# Create a new empty instance
	#
	my $class=shift;
	
	my $obj={};
	
	bless($obj,$class);
}

sub newFromServer {
	#
	# new instance from new server connection
	#
	my $self=shift->new();
	
	$::Statistics->{'total_requests'}++;
	
	my $server=shift;
	my $socket=$server->conSocket();
	
	$self->{'socket'}=$socket;	
	$self->{'socketFN'}=$socket->fileno();
	
	$socket->setNonBlocking();
	
	$self->{'writeBuffer'}='';
	$self->{'readBuffer'}='';
	$self->{'bytesWritten'}=0;
	$self->{'ip'}=$socket->{'connection'}->{'remoteIP'};
	
	push(@Connections,$self);
	
	&::syslog('debug',"New %s for %s",ref($self),$socket->{'connection'}->{'remoteIP'});
	
	$self;
}

###############################################################################
# Instance methods
###############################################################################
sub write {
	my $self=shift;
	
	$self->{'writeBuffer'}.=shift;
	$self->{'writeBufferTimestamp'}=time unless(exists($self->{'writeBufferTimestamp'}));
}

sub addHandleBits {
	my $self=shift;
	
	my $rVecRef=shift;
	my $wVecRef=shift;
	my $eVecRef=shift;
	
	my $fno=$self->{'socketFN'};
	
	if($self->{'writeBuffer'} ne '')
	{
		if(exists($self->{'writeBufferTimestamp'}) && $self->{'writeBufferTimestamp'}+$CONNECTION_WRITE_TIMEOUT<time)
		{
			&::syslog('debug',"%s for %s: write timed out",ref($self),$self->{'socket'}->{'connection'}->{'remoteIP'});
			
			$self->{'writeBuffer'}='';
			$self->close();
			return;
		}
		vec($$wVecRef,$fno,1)=1;
	}

	vec($$rVecRef,$fno,1)=1;
	vec($$eVecRef,$fno,1)=1;
}

sub checkHandleBits {
	my $self=shift;
	
	my $rVec=shift;
	my $wVec=shift;
	my $eVec=shift;
	
	my $fno=$self->{'socketFN'};
	
	if(vec($eVec,$fno,1))
	{
		#
		# Something went wrong!
		#
		$self->exceptionReceived();
		
		return;
	}
	
	if(vec($rVec,$fno,1))
	{
		#
		# Data available for read
		#
		my $socket=$self->{'socket'};
		
		my $buffer='';
		my $bytesRead=sysread($socket->{'handle'},$buffer,$MAX_READ_SIZE);
		if(defined($bytesRead) && $bytesRead>0)
		{
			$::Statistics->{'total_inbound_bytes'}+=$bytesRead;
			$self->{'readBuffer'}.=$buffer;
			while($self->{'readBuffer'}=~s/^([^\r\n]*)\r?\n//)
			{
				$self->processLine($1);
			}
		}
		elsif(defined($bytesRead) && $bytesRead==0)
		{
			# Connection closed
			$self->{'remoteClosed'}=1;
			$self->close(1, 'remoteClosed');
			
			return;
		}
		else
		{
			unless(${!}==EAGAIN)
			{
				&::syslog('notice',"Connection closed: $!");
				$self->{'remoteClosed'}=1;
				$self->close(1, 'remoteClosed');
				
				return;
			}
		}
	}
	
	if(vec($wVec,$fno,1) && $self->{'writeBuffer'} ne '')
	{
		#
		# Can write
		#
		my $socket=$self->{'socket'};
		
		my $bytesWritten=syswrite($socket->{'handle'},$self->{'writeBuffer'});
		
		if(defined($bytesWritten) && $bytesWritten>0)
		{
			$::Statistics->{'total_outbound_bytes'}+=$bytesWritten;
			$self->{'bytesWritten'}+=$bytesWritten;
			$self->{'writeBuffer'}=substr($self->{'writeBuffer'},$bytesWritten);
			if(length($self->{'writeBuffer'})==0)
			{
				delete($self->{'writeBufferTimestamp'});
				$self->close(1) if(exists($self->{'autoClose'}));
			}
			else
			{
				$self->{'writeBufferTimestamp'}=time;
			}
		}
		else
		{
			unless(${!}==EAGAIN)
			{
				&::syslog('notice',"Connection closed: $!");
				$self->{'remoteClosed'}=1;
				$self->close(1, 'remoteClosed');
				
				return;
			}
		}
	}
}

sub exceptionReceived {
	my $self=shift;
	
	$self->{'writeBuffer'}='';
	
	$self->close();
}

sub close {
	my $self=shift;
	
	#&::syslog('debug',"Close called for %s for %s when write buffer empty",ref($self),$self->{'socket'}->{'connection'}->{'remoteIP'});
	
	unless($self->{'remoteClosed'})
	{
		if(!exists($self->{'autoClose'}) && length($self->{'writeBuffer'})>0)
		{
			$self->{'autoClose'}=1;
		
			&::syslog('debug',"Will close %s for %s when write buffer empty",ref($self),$self->{'socket'}->{'connection'}->{'remoteIP'});
		
			return;
		}
	}
	
	eval {
		$self->{'socket'}->close();
	};
	
	#
	# Remove connection from list of connections
	#
	my $idx=undef;
	my $numcon = scalar(@Connections);
	for(my $i=0;$i<$numcon;$i++)
	{
		if($Connections[$i]==$self)
		{
			$idx=$i;
			last;
		}
	}
	
	if(defined($idx))
	{
		splice(@Connections,$idx,1);
	}
	
	&::syslog('debug',"Closed %s for %s",ref($self),$self->{'socket'}->{'connection'}->{'remoteIP'});
	
	$self->didClose();
}

sub didClose {
}

1;
############################################################################EOF