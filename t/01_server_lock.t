use strict;
use warnings;

use Test::More tests => 44;

use App::Lockd::Server::Claim;
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

create();
same();
compatible();
one_callback();
multiple_callbacks();


sub create {
    my $shared = App::Lockd::Server::Claim->shared;
    ok($shared, 'Create shared claim object');
    isa_ok($shared->type, LOCK_SHARED);

    my $excl = App::Lockd::Server::Claim->exclusive;
    ok($excl, 'Create exclusive claim object');
    isa_ok($excl->type, LOCK_EXCLUSIVE);
}

sub same {
    my $shared = App::Lockd::Server::Claim->shared;
    my $excl = App::Lockd::Server::Claim->exclusive;
    ok($shared->is_same_as($shared), 'is same as');
    ok(! $shared->is_same_as($excl), 'different locks are not the same');
    ok(! $excl->is_same_as($shared), 'different locks are not the same both ways');
}

sub compatible {
    my $shared = App::Lockd::Server::Claim->shared;
    my $excl = App::Lockd::Server::Claim->exclusive;
    my $shared2 = App::Lockd::Server::Claim->shared;
    ok($shared->is_compatible_with($shared2), 'Shared locks are compatible with each other');
    ok(! $shared->is_compatible_with($excl), 'Shared lock is not compatible with exclusive lock');
    ok(! $excl->is_compatible_with($shared), 'Exclusive lock is not compatible with shared lock');
}


sub one_callback {
    foreach my $type ( qw(shared exclusive) ) {
        my $c = App::Lockd::Server::Claim->$type;
        ok($c, "made $type claim");

        my $first = 0;
        ok($c->on_success( sub { $first++ } ), 'Add success callback');
        ok($c->signal, 'signal');
        is($first, 1, 'callback was called');

        $first = 0;
        ok($c->signal, 'signal again');
        is($first, 0, 'callback was not called again');

        $first = 0;
        ok($c->on_success( sub { $first++ } ), 'Add a new success callback');
        ok($c->signal, 'signal'),
        is($first, 1, 'New callback was called');
    }
}

sub multiple_callbacks {
    foreach my $type ( qw(shared exclusive) ) {
        my $c = App::Lockd::Server::Claim->$type;
        ok($c, "made $type claim");

        my @called;
        ok($c->on_success( sub { push @called, 1 } ),' Add succes callback');
        ok($c->on_success( sub { push @called, 2 } ),' Add second succes callback');
        ok($c->on_success( sub { push @called, 3 } ),' Add third succes callback');

        ok($c->signal, 'signal');
        is_deeply(\@called, [1,2,3], 'Callbacks were run in the correct order');

        @called = ();
        ok($c->signal, 'signal again');
        is_deeply(\@called, [], 'Callbacks were not re-run');
    }
}
