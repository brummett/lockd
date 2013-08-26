use strict;
use warnings;

use Test::More tests => 75;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::Server::Command::DowngradeLock;
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;
use App::Lockd::LockType qw(LOCK_EXCLUSIVE LOCK_SHARED);

failed_downgrade();
immediate_downgrade_no_waiters();
immediate_downgrade_with_compatible_waiters();
immediate_downgrade_with_incompatible_waiters();
immediate_downgrade_with_mixed_waiters();
downgrade_compatible_waiting_claim();
downgrade_incompatible_waiting_claim();

sub failed_downgrade {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $c = App::Lockd::Server::Claim->shared;
    my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $c,
            success => sub { } );
    ok($success, 'shared lock');

    my $called = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $c,
                    success => sub { $called++ });
    ok(! $success, 'Cannot downgrade a shared lock');
    is($called, 0, 'Callback was not called');
    is($r->state, LOCK_SHARED, 'resource is still shared locked');
    ok($r->is_holding($c), 'Claim is still holding the lock');
}


sub immediate_downgrade_no_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $c = App::Lockd::Server::Claim->exclusive;

    my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $c,
            success => sub { } );
    ok($success, 'excl lock');
    is($r->state, LOCK_EXCLUSIVE, 'resource is excl locked');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $c,
                    success => sub { $downgraded++ });
    ok($success, 'Downgraded lock');
    is($downgraded, 1, 'Callback was called');
    is($r->state, LOCK_SHARED, 'Resource is now shared locked');
    is($c->type, LOCK_SHARED, 'Claim is now type shared');
    ok($r->is_holding($c), 'Claim is still holding the lock');
}

sub immediate_downgrade_with_compatible_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $excl = App::Lockd::Server::Claim->exclusive;
    my $shared1 = App::Lockd::Server::Claim->shared;
    my $shared2 = App::Lockd::Server::Claim->shared;

    my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $excl,
            success => sub { } );
    ok($success, 'excl lock');

    my $shared1_signalled = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $shared1,
            success => sub { $shared1_signalled++ } );
    ok($success, 'add waiting shared lock');
    my $shared2_signalled = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $shared2,
            success => sub { $shared2_signalled++ } );
    ok($success, 'add second waiting shared lock');


    is($r->state, LOCK_EXCLUSIVE, 'resource is excl locked');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $excl,
                    success => sub { $downgraded++ });
    ok($success, 'downgrade lock');
    is($downgraded, 1, 'Callback was called');
    is($r->state, LOCK_SHARED, 'Resource is now exclusive locked');
    is($excl->type, LOCK_SHARED, 'original excl claim is now shared');
    ok($r->is_holding($excl), 'Original claim is still holding the lock');
    ok($r->is_holding($shared1), 'First original shared claim is also holding the lock');
    ok($r->is_holding($shared2), 'Second original shared claim is also holding the lock');
    is($shared1_signalled, 1, 'First original shared claim was signalled');
    is($shared2_signalled, 1, 'Second original shared claim was signalled');
}

sub immediate_downgrade_with_incompatible_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $tested = App::Lockd::Server::Claim->exclusive;
    my $excl1 = App::Lockd::Server::Claim->exclusive;
    my $excl2 = App::Lockd::Server::Claim->exclusive;

    my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $tested,
            success => sub { } );
    ok($success, 'excl lock');

    my $waiter_triggered = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $excl1,
            success => sub { $waiter_triggered++ } );
    ok($success, 'add waiting excl lock');
    my $excl2_triggered = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $excl2,
            success => sub { $waiter_triggered++ } );
    ok($success, 'add second waiting excl lock');


    is($r->state, LOCK_EXCLUSIVE, 'resource is excl locked');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $tested,
                    success => sub { $downgraded++ });
    ok($success, 'downgrade lock');
    is($downgraded, 1, 'Callback was called');
    is($r->state, LOCK_SHARED, 'Resource is now exclusive locked');
    is($tested->type, LOCK_SHARED, 'original excl claim is now shared');
    ok($r->is_holding($tested), 'Original claim is still holding the lock');
    foreach my $waiting ( $excl1, $excl2 ) {
        ok(! $r->is_holding($waiting), 'Original waiting claim is now holding the resource');
        ok($r->is_waiting($waiting), 'Original waiting claim is still waiting');
    }
    is($waiter_triggered, 0, 'None of the waiting claims were signalled');
}

sub immediate_downgrade_with_mixed_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $tested = App::Lockd::Server::Claim->exclusive;
    my $excl = App::Lockd::Server::Claim->exclusive;
    my $shared1 = App::Lockd::Server::Claim->shared;
    my $shared2 = App::Lockd::Server::Claim->shared;

    my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $tested,
            success => sub { } );
    ok($success, 'excl lock');

    my $shared1_signalled = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $shared1,
            success => sub { $shared1_signalled++ } );
    ok($success, 'add waiting shared lock');
    my $excl_signalled = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $excl,
            success => sub { $excl_signalled++ } );
    ok($success, 'add waiting excl lock');
    my $shared2_signalled = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $shared2,
            success => sub { $shared2_signalled++ } );
    ok($success, 'add another waiting shared lock');

    is($r->state, LOCK_EXCLUSIVE, 'resource is excl locked');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $tested,
                    success => sub { $downgraded++ });
    ok($success, 'downgrade lock');
    is($downgraded, 1, 'Callback was called');
    is($r->state, LOCK_SHARED, 'Resource is now exclusive locked');
    is($tested->type, LOCK_SHARED, 'original excl claim is now shared');
    ok($r->is_holding($tested), 'Original claim is still holding the lock');
    foreach my $waiting ( $shared1, $shared2 ) {
        ok($r->is_holding($waiting), 'Original waiting shared claim is holding the resource');
        ok(! $r->is_waiting($waiting), 'Original waiting shared claim is not waiting');
    }
    is($shared1_signalled, 1, 'First original waiting shared claim was signalled');
    is($shared2_signalled, 1, 'Second original waiting shared claim was signalled');

    ok($r->is_waiting($excl), 'Original excl claim is still waiting');
    ok(! $r->is_holding($excl), 'Original excl claim is not holding the resource');
    is($excl_signalled, 0, 'Origin excl claim was not signalled');
}


sub downgrade_compatible_waiting_claim {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $shared = App::Lockd::Server::Claim->shared;
    my $tested = App::Lockd::Server::Claim->exclusive;

    my $success = App::Lockd::Server::Command::Lock->execute(
                    resource => $r,
                    claim => $shared,
                    success => sub {} );
    ok($success, 'shared lock');

    $success = App::Lockd::Server::Command::Lock->execute(
                    resource => $r,
                    claim => $tested,
                    success => sub {} );
    ok($success, 'queue up exclusive lock');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $tested,
                    success => sub { $downgraded++ });
    ok($success, 'Downgrade waiting excl claim');
    is($downgraded, 1, 'Downgrade callback was called');

    is($tested->type, LOCK_SHARED, 'Downgraded claim is now shared');
    ok($r->is_holding($shared), 'original shared lock is holding the resource');
    ok($r->is_holding($tested), 'downgraded lock is also holding the resource');
    ok(! $r->is_waiting($tested), 'downgraded lock is not waiting');
    is($r->state, LOCK_SHARED, 'resource is still shared locked');
}

sub downgrade_incompatible_waiting_claim {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $excl = App::Lockd::Server::Claim->exclusive;
    my $tested = App::Lockd::Server::Claim->exclusive;

    my $success = App::Lockd::Server::Command::Lock->execute(
                    resource => $r,
                    claim => $excl,
                    success => sub {} );
    ok($success, 'excl lock');

    $success = App::Lockd::Server::Command::Lock->execute(
                    resource => $r,
                    claim => $tested,
                    success => sub {} );
    ok($success, 'queue up exclusive lock');

    my $downgraded = 0;
    $success = App::Lockd::Server::Command::DowngradeLock->execute(
                    claim => $tested,
                    success => sub { $downgraded++ });
    ok($success, 'Downgrade waiting excl claim');
    is($downgraded, 1, 'Downgrade callback was called');

    ok($r->is_holding($excl), 'original exclusive lock is holding the resource');
    ok(! $r->is_holding($tested), 'downgraded lock is also holding the resource');
    ok($r->is_waiting($tested), 'downgraded lock is still waiting');
    is($r->state, LOCK_EXCLUSIVE, 'resource is still excl locked');
}
