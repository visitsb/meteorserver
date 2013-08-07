#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	Meteor socket additions
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

package Meteor::Socket;
###############################################################################
# Configuration
###############################################################################
	
	use strict;
	
	use Socket;
	use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
	use Errno qw(EINTR);
	
	BEGIN {
		$Meteor::Socket::handleNum=0;
		
		# Cache getprotobyname result as on some systems it is slow.
		$Meteor::Socket::TCP_PROTO_NAME=getprotobyname('tcp');
		$Meteor::Socket::UDP_PROTO_NAME=getprotobyname('udp');
	}

###############################################################################
# Factory methods
###############################################################################
sub new {
	my $class=shift;
	
	my $self=$class;
	
	unless(ref($class))
	{
		$self={};
		bless($self,$class);
	}
	
	$self->{'timeout'}=0;
	$self->{'buffer'}='';
	
	return $self;
}

sub newWithHandle {
	my $class=shift;
	
	my $self=$class->new;
	$self->{'handle'}=shift;
	
	my $vec='';
	vec($vec,CORE::fileno($self->{'handle'}),1)=1;
	$self->{'handleVec'}=$vec;
	
	my $timeout=shift;
	($timeout) && ($self->{'timeout'}=$timeout);
	
	return $self;
}

sub newServer {
	my($class,$port,$queueSize,$srcIP)=@_;
	
	($port) || die("$class: port undefined!");
	
	$queueSize||=5;
	
	my $self=$class->new;
	
	my $localAdr=INADDR_ANY;
	$localAdr=inet_aton($srcIP) if(defined($srcIP) && $srcIP ne '');
	
	my $local;
	my $sockType=AF_INET;
	my $proto=$Meteor::Socket::TCP_PROTO_NAME;
	
	$self->{'port'}=$port;
	($local=sockaddr_in($port,$localAdr))
		|| die("$class: sockaddr_in for port '$port' failed");
	
	$self->{'handle'}=$self->nextHandle();
	$self->{'socketType'}=$sockType;
	
	socket($self->{'handle'},$sockType,SOCK_STREAM,$proto)
		|| die("$class socket: $!");
	
	setsockopt($self->{'handle'},SOL_SOCKET,SO_REUSEADDR,1);
	
	bind($self->{'handle'},$local)
		|| die("$class bind: $!");
	listen($self->{'handle'},$queueSize)
		|| die("$class listen: $!");
		
	select((select($self->{'handle'}),$|=1)[0]);
	
	my $vec='';
	vec($vec,CORE::fileno($self->{'handle'}),1)=1;
	$self->{'handleVec'}=$vec;
	
	return $self;
}

sub newUDPServer {
	my($class,$port,$srcIP)=@_;
	
	($port) || die("$class: port undefined!");
	
	my $self=$class->new;
	
	my $localAdr=INADDR_ANY;
	$localAdr=inet_aton($srcIP) if(defined($srcIP) && $srcIP ne '');
	
	my $local;
	my $sockType=PF_INET;
	my $proto=$Meteor::Socket::UDP_PROTO_NAME;
	
	$self->{'port'}=$port;
	($local=sockaddr_in($port,$localAdr))
		|| die("$class: sockaddr_in for port '$port' failed");
	
	$self->{'handle'}=$self->nextHandle();
	$self->{'socketType'}=$sockType;
	
	socket($self->{'handle'},$sockType,SOCK_DGRAM,$proto)
		|| die("$class socket: $!");
	
	setsockopt($self->{'handle'},SOL_SOCKET,SO_REUSEADDR,pack("l", 1))
		|| die("setsockopt: $!");
	
	bind($self->{'handle'},$local)
		|| die("$class bind: $!");
		
	select((select($self->{'handle'}),$|=1)[0]);
	
	my $vec='';
	vec($vec,CORE::fileno($self->{'handle'}),1)=1;
	$self->{'handleVec'}=$vec;
	
	return $self;
}

###############################################################################
# Instance methods
###############################################################################
sub DESTROY {
	my $self=shift;
	
	if(exists($self->{'handle'}))
	{
		warn("$self->DESTROY caught unclosed socket")
			unless($Meteor::Socket::NO_WARN_ON_CLOSE);
		$self->close();
	}
}

sub conSocket {
	my $self=shift;
	
	my $handle=$self->nextHandle();
	
	my $paddr;
	$paddr=&saccept($handle,$self->{'handle'}) || die($!);
	
	select((select($handle),$|=1)[0]);
	
	my $newSock=Meteor::Socket->newWithHandle($handle,20);
	$newSock->{'socketType'}=$self->{'socketType'};
	if($self->{'socketType'}==AF_INET)
	{
		my($port,$iaddr)=unpack_sockaddr_in($paddr);
		
		$newSock->{'connection'}->{'port'}=$port;
		$newSock->{'connection'}->{'remoteIP'}=inet_ntoa($iaddr);
	}
	
	return $newSock;
}

sub setNonBlocking {
	my $self=shift;
	
	my $flags=fcntl($self->{'handle'},F_GETFL,0)
		or die("Can't get flags for the socket: $!");
	fcntl($self->{'handle'},F_SETFL,$flags|O_NONBLOCK)
		or die("Can't set flags for the socket: $!");
}

sub close {
	my $self=shift;
	
	if(exists($self->{'handle'}))
	{
		close($self->{'handle'});
		delete($self->{'handle'});
	}
}

###############################################################################
# Utility functions
###############################################################################
sub nextHandle {
	no strict 'refs';
	
	my $name='MSHandle'.$Meteor::Socket::handleNum++;
	my $pack='Meteor::Socket::';
  		my $handle=\*{$pack.$name};
   	delete $$pack{$name};
	
	$handle;
}	

sub sselect {
	my $result;
	my $to=$_[3];
	my $time=time;
	while(1)
	{
		$result=CORE::select($_[0],$_[1],$_[2],$to);
		if($result<0)
		{
			last unless(${!}==EINTR);
			return 0 if($::HUP || $::TERM || $::USR1 || $::USR2);
			my $tn=time;
			$to-=($tn-$time);
			$time=$tn;
			$to=1 if($to<1);
		}
		else
		{
			last;
		}
	}
	
	$result;
}

sub saccept {
	my($dhandle,$shandle)=@_;
	
	my $result;
	while(1)
	{
		$result=CORE::accept($dhandle,$shandle);
		unless($result)
		{
			last unless(${!}==EINTR);
			return 0 if($::HUP || $::TERM || $::USR1 || $::USR2);
		}
		else
		{
			last;
		}
	}
	
	$result;
}

sub fileno {
	CORE::fileno(shift->{'handle'});
}

1;
############################################################################EOF