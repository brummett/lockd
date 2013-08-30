#!/usr/bin/env perl

use App::Lockd::Server::Daemon;

my $d = App::Lockd::Server::Daemon->new();
$d->execute();
