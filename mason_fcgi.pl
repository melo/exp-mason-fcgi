#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

### Default FCGI to a named socket
BEGIN {
  $ENV{FCGI_SOCKET_PATH}  ||= '/tmp/mason_fcgi.sock';
  $ENV{FCGI_LISTEN_QUEUE} ||= 10;
}

use CGI::Fast;
use HTML::Mason::CGIHandler;
use File::Temp;
use Cwd;

### Workspace is a temporary directory, will disappear when the process dies
my $workspace = File::Temp->newdir;

### All the vhosts we support. For each one specify the override comp_root
my %sites = (
  'www.site1.mason' => 'site1',
  'www.site2.mason' => 'site2',
);

### Create the Mason handlers per site
my $base = $ENV{BASE} || getcwd();
my %handlers;

while (my ($site, $comp_base) = each %sites) {
  $handlers{$site} = HTML::Mason::CGIHandler->new(
    comp_root =>
      [[$comp_base => "$base/$comp_base"], [master => "$base/master"],],
    data_dir   => $workspace->dirname,
    error_mode => 'output',
  );
}

{
  ### Usefull debug commands in the component namespace
  package HTML::Mason::Commands;
  use Data::Dumper;
  use vars qw( %stash );
}

### Preserve our stderr for logging
open(my $error_log, ">&", \*STDERR) || die "Could not dup STDERR: $!,";
print $error_log "** Ready for requests\n** Workdir is: "
  . $workspace->dirname . "\n\n";


### request loop: foreach one, decide which vhost is the target, and call appropriate handler
while (my $cgi = new CGI::Fast()) {
  my ($host) = $ENV{HTTP_HOST} =~ /^(.+?)(:\d+)?$/;
  print $error_log ">> HIT for '$host' => '$ENV{REQUEST_URI}'\n";

  ### Make sure we have a clean stash when we start
  %HTML::Mason::Commands::stash = ();
  
  # hand off to mason
  # FIXME: need to deal with unknown sites
  eval { $handlers{$host}->handle_cgi_object($cgi) };
  if (my $raw_error = $@) {
    print $error_log $raw_error;
  }
  
  ### And release the stash after the request
  %HTML::Mason::Commands::stash = ();
}

exit 0;
