use strict;
use warnings;

use Test::More tests => 46;

use App::Lockd::Server::Claim;
use App::Lockd::Server::Resource;
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

create();
same();
compatible();
one_callback();
multiple_callbacks();


sub create {
    my $r = App::Lockd::Server::Resource->get('foo');

    my $shared = App::Lockd::Server::Claim->shared(resource => $r);
    ok($shared, 'Create shared claim object');
    isa_ok($shared->type, LOCK_SHARED);
    is($shared->resource, $r, 'resource attribute');

    my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);
    ok($excl, 'Create exclusive claim object');
    isa_ok($excl->type, LOCK_EXCLUSIVE);
    is($excl->resource, $r, 'resource attribute');
}

sub same {
    my $r = App::Lockd::Server::Resource->get('foo');

    my $shared = App::Lockd::Server::Claim->shared(resource => $r);
    my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);
    ok($shared->is_same_as($shared), 'is same as');
    ok(! $shared->is_same_as($excl), 'different locks are not the same');
    ok(! $excl->is_same_as($shared), 'different locks are not the same both ways');
}

sub compatible {
    my $r = App::Lockd::Server::Resource->get('foo');

    my $shared = App::Lockd::Server::Claim->shared(resource => $r);
    my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);
    my $shared2 = App::Lockd::Server::Claim->shared(resource => $r);
    ok($shared->is_compatible_with($shared2), 'Shared locks are compatible with each other');
    ok(! $shared->is_compatible_with($excl), 'Shared lock is not compatible with exclusive lock');
    ok(! $excl->is_compatible_with($shared), 'Exclusive lock is not compatible with shared lock');
}


sub one_callback {
    my $r = App::Lockd::Server::Resource->get('foo');

    foreach my $type ( qw(shared exclusive) ) {
        my $c = App::Lockd::Server::Claim->$type(resource => $r);
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
    my $r = App::Lockd::Server::Resource->get('foo');

    foreach my $type ( qw(shared exclusive) ) {
        my $c = App::Lockd::Server::Claim->$type(resource => $r);
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
