use strict;
use warnings;

use Test::More tests => 31;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

shared_then_exclusive();
exclusive_then_shared();

sub shared_then_exclusive {
    note('shared then exclusive');

    my $r = App::Lockd::Server::Resource->get(__LINE__);

    my $shared_lock1 = App::Lockd::Server::Claim->shared(resource => $r);

    # one shared lock
    my $first = 0;
    my $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $shared_lock1,
                    success => sub { $first++} );
    ok($success, 'lock shared');
    ok($r->is_locked, 'resource is locked');
    is($r->state, LOCK_SHARED, 'resource is shared locked');
    is($first, 1, 'Callback ran');


    # Try getting excl lock - will be queued
    my $second = 0;
    my $excl_lock = App::Lockd::Server::Claim->exclusive(resource => $r);
    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $excl_lock,
                    success => sub { $second++ } );
    ok($success, 'add exclusive lock');
    ok($r->is_locked, 'resource is still locked');
    is($r->state, LOCK_SHARED, 'resource is still shared locked');
    is($second, 0, 'Second exclusive lock was not signalled');


    # attach another shared lock
    my $shared_lock2 = App::Lockd::Server::Claim->shared(resource => $r);
    my $third = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $shared_lock2,
                    success => sub { $third++ } );
    ok($success, 'lock shared again');
    is($third, 1, 'Lock was signalled');
    is($second, 0, 'excl lock still was not signalled');


    # release the two shared locks
    $success = App::Lockd::Server::Command::Release->execute( claim => $shared_lock1 );
    ok($success, 'release first shared lock');
    is($second, 0, 'excl lock still was not signalled');
    is($r->state, LOCK_SHARED, 'Resource is still shared locked');

    $success = App::Lockd::Server::Command::Release->execute( claim => $shared_lock2 );
    ok($success, 'release second shared lock');
    is($second, 1, 'excl lock was signalled');
    is($r->state, LOCK_EXCLUSIVE, 'Resource is now exclusive locked');
}

sub exclusive_then_shared {
    note('exclusive then shared');

    my $r = App::Lockd::Server::Resource->get(__LINE__);

    my $excl_lock1 = App::Lockd::Server::Claim->exclusive(resource => $r);
    my $first = 0;
    my $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $excl_lock1,
                    success => sub { $first++ } );
    ok($success, 'exclusive lock');
    is($first, 1, 'excl lock still was signalled');
    is($r->state, LOCK_EXCLUSIVE, 'Resource is exclusive locked');
    

    my $shared_lock1 = App::Lockd::Server::Claim->shared(resource => $r);
    my $shared_lock2 = App::Lockd::Server::Claim->shared(resource => $r);
    my $excl_lock2 = App::Lockd::Server::Claim->exclusive(resource => $r);

    my $shared_1 = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $shared_lock1,
                    success => sub { $shared_1++ } );
    ok($success, 'add shared lock');
    is($shared_1, 0, '... was not signalled');

    my $excl_2 = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $excl_lock2,
                    success => sub { $excl_2++ } );
    ok($success, 'add another exclusive lock');
    is($excl_2, 0, '... was not signalled');

    my $shared_2 = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $shared_lock2,
                    success => sub { $shared_2++ } );
    ok($success, 'add another shared lock');
    is($shared_2, 0, '... was not signalled');


    $success = App::Lockd::Server::Command::Release->execute( claim => $excl_lock1 );
    ok($success, 'release first exclusive lock');
    is($shared_1, 1, 'first shared lock was signalled');
    is($shared_2, 1, 'second shared lock was signalled');
    is($r->state, LOCK_SHARED, 'Resource is now shared locked');

    is($excl_2, 0, 'second exclusive lock was not signalled');
}
