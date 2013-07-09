#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	Convenience interface to syslog
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

package Meteor::Syslog;
###############################################################################

	use strict;
	use Sys::Syslog;
	
###############################################################################
# Configuration
###############################################################################

	$Meteor::Syslog::DEFAULT_FACILITY='daemon';
	
	$Meteor::Syslog::_open=0;		# set to 1 by _open
	
###############################################################################
# Implementation
###############################################################################
sub ::syslog {
	
	my $debug=$::CONF{'Debug'};
	
	my $priority=shift;
	return if($priority eq 'debug' && !$debug);
	
	my $format=shift;
	my @args=@_;
	
	if($format eq '')
	{
		my $txt=join("\t",@args);
		$format='%s';
		@args=($txt);
	}
	
	my $facility=$::CONF{'SyslogFacility'} || $Meteor::Syslog::DEFAULT_FACILITY;
	
	if($debug || $facility eq 'none')
	{
		$format=~s/\%m/$!/g;
		
		my $time = ($::CONF{'LogTimeFormat'} eq 'unix') ? time : localtime(time);
		
		print STDERR "$time\t$priority\t";
		print STDERR sprintf($format,@args);
		print STDERR "\n" unless(substr($format,-1) eq "\n");
		
		return;
	}
	
	unless($Meteor::Syslog::_open)
	{
		my $facility=$::CONF{'SyslogFacility'} || $Meteor::Syslog::DEFAULT_FACILITY;
		openlog($::PGM,0,$facility);
		$Meteor::Syslog::_open=1;
	}
	
	syslog($priority,$format,@args);
}

sub myWarn {
	local $SIG{'__DIE__'}='';
	local $SIG{'__WARN__'}='';
	
	&::syslog('warning',$_[0]);
}

sub myDie {
	local $SIG{'__DIE__'}='';
	local $SIG{'__WARN__'}='';
		
	my $inEval=0;
	my $i=0;
	my $sub;
	while((undef,undef,undef,$sub)=caller(++$i))
	{
		$inEval=1, last if $sub eq '(eval)';
	}
	
	unless($inEval)
	{
		&::syslog('err',$_[0]);
		$Meteor::Socket::NO_WARN_ON_CLOSE=1;
		exit;
	}
}

1;
############################################################################EOF