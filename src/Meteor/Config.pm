#!/usr/bin/perl -w
###############################################################################
#   Meteor
#   An HTTP server for the 2.0 web
#   Copyright (c) 2006 contributing authors
#
#   Subscriber.pm
#
#	Description:
#	Meteor Configuration handling.
#
#	Main program should call Meteor::Config::setCommandLineParameters(@ARGV),.
#	Afterwards anybody can access $::CONF{<parameterName>}, where
#	<parameterName> is any valid parameter (except 'Help') listed in the
#	@DEFAULTS array below.
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

package Meteor::Config;
###############################################################################
# Configuration
###############################################################################
	
	use strict;
	
	our @DEFAULTS=(
'Template for each line in channelinfo',
	ChannelInfoTemplate		=> '<script>ch("~name~", ~lastMsgID~);</script>\r\n',

'Configuration file location on disk (if any)',
	ConfigFileLocation		=> '/etc/meteord.conf',

'IP address for controller server (leave empty for all local addresses)',
	ControllerIP			=> '',

'Port number for controller connections',
	ControllerPort			=> 4671,

'Controller Shutdown message, sent when the controller server shuts down (leave empty for no message)',
	ControllerShutdownMsg	=> '',

'Debug Flag, when set daemon will run in foreground and emit debug messages',
	Debug					=> 0,
	
'Name of index file to serve when a directory is requested from the static file web server',
	DirectoryIndex	=> 'index.html',

'Header template, ~server~, ~servertime~ and ~status~ will be replaced by the appropriate values.',
	HeaderTemplate			=> 'HTTP/1.1 ~status~\r\nServer: ~server~\r\nContent-Type: text/html; charset=utf-8\r\nPragma: no-cache\r\nCache-Control: no-cache, no-store, must-revalidate\r\nExpires: Thu, 1 Jan 1970 00:00:00 GMT\r\n\r\n',

'Print out this help message',
	Help					=> '',

'Format to use for timestamps in syslog: unix or human',
	LogTimeFormat			=> 'human',

'Maximum age of a message in seconds',
	MaxMessageAge			=> 7200,

'Maximum number of messages to send to a subscriber before forcing their connection to close. Use 0 to disable',
	MaxMessages				=> 0,

'Maximum number of stored messages per channel',
	MaxMessagesPerChannel	=> 250,

'Maximum duration in seconds for a subscriber connection to exist before forcing a it to close. Note that the server checks for expired connections in 60 second intervals, so small changes to this value will not have much of an effect. Use 0 to disable',
	MaxTime					=> 0,

'Message template, ~text~, ~id~, ~channel~ and ~timestamp~ will be replaced by the appropriate values',
	MessageTemplate			=> '<script>p(~id~,"~channel~","~text~");</script>\r\n',

'Interval at which PingMessage is sent to all persistent subscriber connections. Must be at least 3 if set higher than zero. Set to zero to disable.',
	PingInterval			=> 5,

'Persistence of a connection.',
	Persist					=> 0,

'Message to be sent to all persistent subscriber connections (see above) every PingInterval seconds',
	PingMessage				=> '<script>p(-1,"");</script>\r\n',

'IP address for subscriber server (leave empty for all local addresses)',
	SubscriberIP			=> '',

'Port number for subscriber connections',
	SubscriberPort			=> 4670,

'Subscriber Shutdown message, sent when the subscriber server shuts down (leave empty for no message)',
	SubscriberShutdownMsg		=> '<script>eof();</script>\r\n',

'An absolute filesystem path, to be used as the document root for Meteor\'s static file web server. If left empty, no documents will be served.',
	SubscriberDocumentRoot	=> '/usr/local/meteor/public_html',

'Since Meteor is capable of serving static pages from a document root as well as streaming events to subscribers, this parameter is used to specify the URI at which the event server can be reached. If set to the root, Meteor will lose the ability to serve static pages.',
	SubscriberDynamicPageAddress	=> '/push',

'The syslog facility to use',
	SyslogFacility			=> 'daemon',
	
'IP address for udp server (leave empty for all local addresses)',
	UDPIP					=> '',
	
'Port number for udp connections, set to 0 to disable',
	UDPPort					=> 0,

	);
	
	our %ConfigFileData=();
	our %CommandLine=();
	our %Defaults=();
	our %Modes=();
	
	for(my $i=0;$i<scalar(@DEFAULTS);$i+=3)
	{
		$Defaults{$DEFAULTS[$i+1]}=$DEFAULTS[$i+2];
	}

###############################################################################
# Class methods
###############################################################################
sub updateConfig {
	my $class=shift;
	
	%::CONF=();
	
	my $debug=$class->valueForKey('Debug');
	
	print STDERR '-'x79 ."\nMeteor server v$::VERSION (release date: $::RELEASE_DATE)\r\nLicensed under the terms of the GNU General Public Licence (2.0)\n".'-'x79 ."\n" if($debug);
	
	my @keys=();
	
	for(my $i=0;$i<scalar(@DEFAULTS);$i+=3)
	{
		next if($DEFAULTS[$i+1] eq 'Help');
		push(@keys,$DEFAULTS[$i+1]);
	}
	
	foreach my $mode ('',keys %Modes)
	{
		print STDERR ($mode) ? "\r\n$mode:\r\n" : "\r\nDefaults:\r\n" if($debug);
		foreach my $baseKey (@keys)
		{
			my $foundValue=0;
			my $key=$baseKey.$mode;
			
			if(exists($CommandLine{$key}))
			{
				print STDERR "CmdLine" if($debug);
				$::CONF{$key}=$CommandLine{$key};
				$foundValue=1;
			}
			elsif(exists($ConfigFileData{$key}))
			{
				print STDERR "CnfFile" if($debug);
				$::CONF{$key}=$ConfigFileData{$key};
				$foundValue=1;
			}
			elsif(exists($Defaults{$key}))
			{
				print STDERR "Default" if($debug);
				$::CONF{$key}=$Defaults{$key};
				$foundValue=1;
			}
			
			next unless($foundValue);
			
			print STDERR "\t$baseKey\t$::CONF{$key}\n" if($debug);
			
			# Take care of escapes
			$::CONF{$key}=~s/\\(.)/
				if($1 eq 'r') {
					"\r";
				} elsif($1 eq 'n') {
					"\n";
				} elsif($1 eq 's') {
					' ';
				} elsif($1 eq 't') {
					"\t";
				} elsif($1 eq '0') {
					"\0";
				} else {
					$1;
				}
			/gex;
		}
	}
	print STDERR '-'x79 ."\n" if($debug);
}

sub valueForKey {
	my $class=shift;
	my $key=shift;
	
	return $CommandLine{$key} if(exists($CommandLine{$key}));
	return $ConfigFileData{$key} if(exists($ConfigFileData{$key}));
	
	$Defaults{$key};
}

sub setCommandLineParameters {
	my $class=shift;
	
	#
	# Quick check if we should show the version, if so ignore everything else
	# Accept -v, -version, and everything in between
	# 
	foreach my $p (@_)
	{
		if(index($p,'-v')==0 && index('-version',$p)==0)
		{
			print "$::PGM $::VERSION\n";
			exit(0);
		}
	}
	
	while(my $cnt=scalar(@_))
	{
		my $k=shift(@_);
		&usage("'$k' invalid") unless($k=~s/^\-(?=.+)//);
		
		$k='Debug' if($k eq 'd');
		
		my $mode='';
		
		if($k=~s/(\.(.+))$//)
		{
			$mode=$2;
			$Modes{$mode}=1;
		}
		
		my $key=undef;
		my $kl=length($k);
		my $kOrig=$k;
		$k=lc($k);
		
		for(my $i=0;$i<scalar(@DEFAULTS);$i+=3)
		{
			my $p=$DEFAULTS[$i+1];
			my $pl=length($p);
			
			next if($kl>$pl);
			
			#print "$kl $pl $k $p\n";
			
			if($kl==$pl && $k eq lc($p))
			{
				$key=$p;
				last;
			}
			
			my $ps=lc(substr($p,0,$kl));
			
			if($k eq $ps)
			{
				if(defined($key))
				{
					&usage("Ambigous parameter name '$kOrig'");
				}
				$key=$p;
			}
		}
			
		&usage("Unknown parameter name '$kOrig'") unless(defined($key));
		
		&usage() if($key eq 'Help');
		
		#print "$kOrig: $key\n";
		
		$CommandLine{"$key$mode"}=1;
		
		if($cnt>1 && $_[0]!~/^\-(?!\-)/)
		{
			my $param=shift;
			$param=~s/^\-\-/\-/;
			$CommandLine{"$key$mode"}=$param;
		}
	}
	
	$class->readConfig();
	
	$class->updateConfig();
}

sub readConfig {
	my $class=shift;
	
	%ConfigFileData=();
	
	my $path=$class->valueForKey('ConfigFileLocation');
	return unless(defined($path) && -f $path);
	
	my $mode='';
	
	open(CONFIG,"$path") or &usage("Config file '$path' for read: $!\n");
	while(<CONFIG>)
	{
		next if(/^\s*#/);
		next if(/^\s*$/);
		
		s/[\r\n]*$//;
		
		if(/^\s*\[\s*([^\]\s]+)\s*\]\s*$/)
		{
			$Modes{$1}=1;
			$mode = $1;
			next;
		}
		
		unless(/^(\S+)\s*(.*)/)
		{
			&usage("Invalid configuration file parameter line '$_'");
		}
		
		my $key=$1;
		my $val=$2;
		$val='' unless(defined($val));
		
		unless(exists($Defaults{$key}))
		{
			&usage("Unknown configuration file parameter name '$key$mode'");
		}
		if($key eq 'ConfigFileLocation')
		{
			&usage("'ConfigFileLocation' parameter not allowed in configuration file!");
		}
		
		$val=~s/^--/-/;
		
		$ConfigFileData{"$key$mode"}=$val;
	}
	close(CONFIG);
}

sub usage {
	my $msg=shift || '';
	
	if($msg) {
		print STDERR <<"EOT";
$msg;
For further help type $::PGM -help
or consult docs at http://meteorserver.org/
EOT

	} else {

	
		print STDERR <<"EOT";

Meteor server v$::VERSION (release date: $::RELEASE_DATE)
Licensed under the terms of the GNU General Public Licence (2.0)

Usage:

	$::PGM [-parameter [value] [-parameter [value]...]]

Accepted command-line parameters:

EOT
	
		for(my $i=0;$i<scalar(@DEFAULTS);$i+=3)
		{
			print STDERR "-$DEFAULTS[$i+1]\n$DEFAULTS[$i].\n\n";
		}
		
		print STDERR <<"EOT";	
	
Any of the parameters listed above can also be configured in the
configuration file. The default location for this file is:

	$Defaults{'ConfigFileLocation'}

For more information and complete documentation, see the Meteor
website at http://meteorserver.org/
EOT

	}
	exit(1);
}

1;
############################################################################EOF