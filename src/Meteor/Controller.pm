#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	A Meteor Controller
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

package Meteor::Controller;
###############################################################################
# Configuration
###############################################################################
	
	use strict;
	
	use Meteor::Connection;
	use Meteor::Channel;
	use Meteor::Subscriber;
	
	@Meteor::Controller::ISA=qw(Meteor::Connection);

###############################################################################
# Factory methods
###############################################################################
sub newFromServer {
	my $class=shift;
	
	my $self=$class->SUPER::newFromServer(shift);
	
	$::Statistics->{'current_controllers'}++;
	$::Statistics->{'controller_connections_accepted'}++;
	
	$self;
}

###############################################################################
# Instance methods
###############################################################################
sub processLine {
	my $self=shift;
	my $line=shift;
	
	# ADDMESSAGE channel1 Message text
	# < OK
	# ADDMESSAGE
	# < ERR Invalid command syntax
	# COUNTSUBSCRIBERS channel1
	# < OK 344
	
	unless($line=~s/^(ADDMESSAGE|COUNTSUBSCRIBERS|LISTCHANNELS|SHOWSTATS|QUIT)//)
	{
		$self->write("ERR Invalid command syntax$::CRLF");
		
		return;
	}
	
	my $cmd=$1;
	
	if($cmd eq 'ADDMESSAGE')
	{
		unless($line=~s/^\s+(\S+)\s//)
		{
			$self->write("ERR Invalid command syntax$::CRLF");
			
			return;
		}
		
		my $channelName=$1;
		my $channel=Meteor::Channel->channelWithName($channelName);
		my $msg=$channel->addMessage($line);
		my $msgID=$msg->id();
		$self->write("OK\t$msgID$::CRLF");
	}
	elsif($cmd eq 'COUNTSUBSCRIBERS')
	{
		unless($line=~s/^\s+(\S+)$//)
		{
			$self->write("ERR Invalid command syntax$::CRLF");
			
			return;
		}
		
		my $channelName=$1;
		my $numSubscribers=0;
		my $channel=Meteor::Channel->channelWithName($channelName,1);
		$numSubscribers=$channel->subscriberCount() if($channel);
		
		$self->write("OK $numSubscribers$::CRLF");
	}
	elsif($cmd eq 'LISTCHANNELS')
	{
		unless($line eq '')
		{
			$self->write("ERR Invalid command syntax$::CRLF");
			
			return;
		}
		
		my $txt="OK$::CRLF".Meteor::Channel->listChannels()."--EOT--$::CRLF";
		
		$self->write($txt);
	}
	elsif($cmd eq 'SHOWSTATS')
	{
		# uptime
		my $uptime=time-$::STARTUP_TIME;
		my $txt="OK$::CRLF"."uptime: $uptime$::CRLF";
		
		# channel_count
		my $numChannels=Meteor::Channel->numChannels();
		$txt.="channel_count: $numChannels$::CRLF";
		
		foreach my $key (keys %{$::Statistics})
		{
			$txt.=$key.': '.$::Statistics->{$key}.$::CRLF;
		}
		
		$txt.="--EOT--$::CRLF";
		
		$self->write($txt);
	}
	elsif($cmd eq 'QUIT')
	{
		unless($line eq '')
		{
			$self->write("ERR Invalid command syntax$::CRLF");
			
			return;
		}
		
		$self->write("OK$::CRLF");
		$self->close(1);
	}
	else
	{
		# Should never get here
		die("Unknown command '$cmd'");
	}
}

sub close {
	my $self=shift;
	my $noShutdownMsg=shift;
	
	unless($noShutdownMsg || $self->{'remoteClosed'})
	{
		my $msg=$::CONF{'ControllerShutdownMsg'};
		if(defined($msg) && $msg ne '')
		{
			$self->write($msg);
		}
	}
	
	$self->SUPER::close();
}

sub didClose {
	
	$::Statistics->{'current_controllers'}--;
}

1;
############################################################################EOF