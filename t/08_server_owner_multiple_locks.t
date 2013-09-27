use strict;
use warnings;

use Test::More tests => 262;

#$SIG{ALRM} = sub { ok(0,' Took too long'); exit(1); };
#alarm(10);

use App::Lockd::Server::Owner;
use Sys::Hostname qw();
use AnyEvent;

use File::Basename;
use lib File::Basename::dirname(__FILE__).'/lib';
use AnyEventHandleFake;

multiple_same_resource_same_owner();
multiple_different_locks();

multiple_same_shared();
multiple_same_exclusive();

shared_exclusive_shared();
exclusive_shared_shared();

sub multiple_same_resource_same_owner {
    foreach my $lock_type ( qw( shared exclusive ) ) {
        note("multiple_same_resource_same_owner: $lock_type");

        my $owner = OwnerTest->new( fh => 'fh');
        isa_ok($owner, 'App::Lockd::Server::Owner');

        lock_get_response($owner, 'shared', 'foo');

        lock_get_response($owner,
                            'shared',
                            'foo',
                            qr(^resource foo is already claimed));

        release_get_response($owner, 'foo');
    }
}

sub multiple_different_locks {
    # Should work the same whether there's one owner or two,
    # whether they're shared or exclusive locks
    foreach my $lock_type ( qw( shared exclusive ) ) {
        foreach my $owner ( [ OwnerTest->new( fh => 'fh') ],
                            [ OwnerTest->new( fh => 'fh'), OwnerTest->new( fh => 'fh') ],
        ) {
            note("multiple_different_locks: $lock_type ".scalar(@$owner)." different owners");

            my @owner = @$owner;
            $owner[1] ||= $owner[0];  # firse case, same owner

            foreach (@owner) {
                isa_ok($_, 'App::Lockd::Server::Owner');
            }

            lock_get_response($owner[0], $lock_type, 'foo');

            lock_get_response($owner[1], $lock_type, 'bar');

            release_get_response($owner[0], 'foo');

            release_get_response($owner[1], 'bar');
        }
    }
}

sub multiple_same_shared {
    my @owners = map { OwnerTest->new( fh => 'fh') } ( 1,2,3 );

    foreach my $owner (@owners) {
        lock_get_response($owner, 'shared', 'foo');
    }

    foreach my $owner ( @owners ) {
        release_get_response($owner, 'foo');
    }
}


sub multiple_same_exclusive {
    my($first, $second) = map { OwnerTest->new( fh => 'fh') } ( 1,2 );

    lock_get_response($first, 'exclusive', 'foo');

    lock_no_response($second, 'exclusive', 'foo');

    release_get_response($first, 'foo');

    delayed_success($second, 'exclusive', 'foo');

    release_get_response($second, 'foo');
}

sub shared_exclusive_shared {
    note('shared_exclusive_shared');

    my $result;
    my @shared = map { OwnerTest->new( fh => 'fh') } ( 1,2 );
    my $excl   = OwnerTest->new( fh => 'fh');

    lock_get_response($shared[0], 'shared', 'foo');

    lock_no_response($excl, 'exclusive', 'foo');

    lock_get_response($shared[1], 'shared', 'foo');

    release_get_response($shared[0], 'foo');

    $result = $shared[1]->watcher->_written_data;
    is(scalar(@$result), 0, 'No response to other shared owner');
    $result = $excl->watcher->_written_data;
    is(scalar(@$result), 0, 'No response to other excl owner');

    release_get_response($shared[1], 'foo');

    $result = $shared[0]->watcher->_written_data;
    is(scalar(@$result), 0, 'No response to first shared owner');

    delayed_success($excl, 'exclusive', 'foo');

    release_get_response($excl, 'foo');

    foreach my $shared ( @shared ) {
        my $r = $shared->watcher->_written_data;
        is(scalar(@$r), 0, 'No response to shared owner');
    }
}


sub exclusive_shared_shared {
    note('exclusive_shared_shared');
    my @shared = map { OwnerTest->new( fh => 'fh') } ( 1,2 );
    my $excl   = OwnerTest->new( fh => 'fh');

    lock_get_response($excl, 'exclusive', 'foo');

    foreach my $shared ( @shared ) {
        lock_no_response($shared, 'shared', 'foo');
    }

    release_get_response($excl, 'foo');

    foreach my $shared ( @shared ) {
        delayed_success($shared, 'shared', 'foo');
    }

    foreach my $shared ( @shared ) {
        release_get_response($shared, 'foo');
    }
}


sub lock_get_response {
    my($owner, $type, $resource, $expected_response) = @_;

    my $watcher = $owner->watcher;
    $watcher->_queue_input(make_lock_message($type, $resource));

    _check_successful_response($owner, $type, $resource, $expected_response);
}

sub _check_successful_response {
    my($owner, $type, $resource, $expected_response) = @_;

    $expected_response = qr(^OK$) unless defined ($expected_response);

    my $result = $owner->watcher->_written_data;

    is(scalar(@$result), 1, "Got one result from $type lock");
    is($result->[0]->{owner}, '123', 'result owner');
    is($result->[0]->{command}, 'lock', 'result command');
    is($result->[0]->{type}, $type, 'result type');
    is($result->[0]->{resource}, $resource, 'result resource');
    like($result->[0]->{response}, $expected_response, 'result response');
}


sub lock_no_response {
    my($owner, $type, $resource) = @_;

    my $watcher = $owner->watcher;
    $watcher->_queue_input(make_lock_message($type, $resource));
    my $result = $watcher->_written_data;

    is(scalar(@$result), 0, "Got no response yet from $type lock");
}

sub release_get_response {
    my($owner, $resource) = @_;

    my $watcher = $owner->watcher;
    $watcher->_queue_input(make_release_message($resource));
    my $result = $watcher->_written_data;
    is(scalar(@$result), 1, "Got back one result from releasing second lock");
    is($result->[0]->{owner}, '123', 'result owner');
    is($result->[0]->{command}, 'release', 'result command');
    is($result->[0]->{resource}, $resource, 'result resource');
    is($result->[0]->{response}, 'OK', 'result response');
}

sub delayed_success {
    my($owner, $type, $resource, $expected_response) = @_;
    _check_successful_response($owner, $type, $resource, $expected_response);
}

sub make_lock_message {
    my($type, $resource) = @_;
    return {
        owner => '123',
        time  => time(),
        command => 'lock',
        type => $type,
        resource => $resource
    };
}

sub make_release_message {
    my($resource) = @_;
    return {
        owner => '123',
        time  => time(),
        command => 'release',
        resource => $resource,
    };
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

