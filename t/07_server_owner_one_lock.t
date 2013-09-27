use strict;
use warnings;

use Test::More tests => 28;

unless (defined &DB::DB) {
    $SIG{ALRM} = sub { ok(0,' Took too long'); exit(1); };
    alarm(10);
}

use App::Lockd::Server::Owner;
use Sys::Hostname qw();
use AnyEvent;

use File::Basename;
use lib File::Basename::dirname(__FILE__).'/lib';
use AnyEventHandleFake;

one_lock();

sub one_lock {
    foreach my $lock_type ( qw( shared exclusive ) ) {
        my $owner = OwnerTest->new( fh => 'fh');
        isa_ok($owner, 'App::Lockd::Server::Owner');

        my $watcher = $owner->watcher;

        my $time = time();
        $watcher->_queue_input({
            owner => '123',
            time => $time,
            command => 'lock',
            type => $lock_type,
            resource => 'foo'});
        

        my $result = $watcher->_written_data;
        is(scalar(@$result), 1, "Got back one result from $lock_type locking");
        is($result->[0]->{command}, 'lock', 'response command');
        is($result->[0]->{owner}, '123', 'response owner');
        is($result->[0]->{type}, $lock_type, 'response type');
        is($result->[0]->{resource}, 'foo', 'response resource');
        is($result->[0]->{time}, $time, 'response time');
        is($result->[0]->{response}, 'OK', 'response response');


        $time = time();
        $watcher->_queue_input({
            owner => '123',
            time  => $time,
            command => 'release',
            resource => 'foo'});

        $result = $watcher->_written_data;
        is(scalar(@$result), 1, "Got back one result from $lock_type release");
        is($result->[0]->{command}, 'release', 'response command');
        is($result->[0]->{owner}, '123', 'response owner');
        is($result->[0]->{resource}, 'foo', 'response resource');
        is($result->[0]->{time}, $time, 'response time');
        is($result->[0]->{response}, 'OK', 'response response');
    }
}


package OwnerTest;

use App::Lockd::Server::Owner;
BEGIN {
    our @ISA = qw(App::Lockd::Server::Owner);
}

sub cv {
    my $self = shift;
    if (@_) {
        $self->{cv} = shift;
    }
    return $self->{cv};
}

sub _create_watcher {
    my $self = shift;
    if ($self->cv) {
        $self->cv->send(['_create_watcher']);
    }
    return $self->watcher(AnyEventHandleFake->new());
}

