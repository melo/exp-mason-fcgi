#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

BEGIN {
  $ENV{FCGI_SOCKET_PATH}  ||= '/tmp/mason_fcgi.sock';
  $ENV{FCGI_LISTEN_QUEUE} ||= 10;
}

use CGI::Fast;
use HTML::Mason::CGIHandler;
use File::Temp;
use Cwd;

my $workspace = File::Temp->newdir;
my $base = $ENV{BASE} || getcwd();
my %handlers;

my %sites = (
  'cat1' => 'site1',
  'cat2' => 'site2',
);

while (my ($site, $comp_base) = each %sites) {
  $handlers{$site} = HTML::Mason::CGIHandler->new(
    comp_root => [
      [$comp_base => "$base/$comp_base"],
      [master     => "$base/master"],
    ],
    data_dir   => $workspace->dirname,
    error_mode => 'output',
  );
}

{
  package HTML::Mason::Commands;
  use Data::Dumper;
}

open(my $error_log, ">&", \*STDERR) || die "Could not dup STDERR: $!,";
print $error_log "** Ready for requests\n** Workdir is: "
  . $workspace->dirname . "\n\n";

while (my $cgi = new CGI::Fast()) {
  my ($host) = $ENV{HTTP_HOST} =~ /^(.+?)(:\d+)?$/;
  print $error_log ">> HIT for '$host' => '$ENV{REQUEST_URI}'\n";

  # hand off to mason
  # FIXME: need to deal with unknown sites
  eval { $handlers{$host}->handle_cgi_object($cgi) };
  if (my $raw_error = $@) {
    print $error_log $@;
  }
}

exit 0;
