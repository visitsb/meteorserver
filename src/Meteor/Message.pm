#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	Meteor message object
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

package Meteor::Message;
###############################################################################
# Configuration
###############################################################################
	
	use strict;

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
	
sub newWithID {
	#
	# new instance from new server connection
	#
	my $self=shift->new();
	my $id=shift;
	my $text=shift || '';
	
	$self->{'timestamp'}=time;
	$self->{'id'}=$id;
	$self->{'text'}=$text;
	
	$::Statistics->{'unique_messages'}++;
		
	$self;
}

###############################################################################
# Instance methods
###############################################################################
sub setText {
	my $self=shift;
	my $text=shift || '';
	
	$self->{'text'}=$text;
}

sub channelName {
	shift->{'channel'};
}

sub setChannelName {
	my $self=shift;
	my $channelName=shift || '';
	
	$self->{'channel'}=$channelName;
}

sub text {
	shift->{'text'};
}

sub id {
	shift->{'id'};
}

sub timestamp {
	shift->{'timestamp'};
}

sub message {
	
	shift->messageWithTemplate($::CONF{'MessageTemplate'});
}

sub messageWithTemplate {
	my $self=shift;
	my $msg=shift;
	
	$msg=~s/~([^~]*)~/
		if(!defined($1) || $1 eq '')
		{
			'~';
		}
		elsif(exists($self->{$1}))
		{
			$self->{$1};
		}
		else
		{
			'';
		}
	/gex;
	
	$msg;
}

1;
############################################################################EOF