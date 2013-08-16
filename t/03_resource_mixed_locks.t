use strict;
use warnings;

use Test::More tests => 30;

use App::Lockd::Server::Resource;
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

use lib 't/lib';
use FakeLock;

shared_then_exclusive();
exclusive_then_shared();

sub shared_then_exclusive {
    note('shared then exclusive');

    my $r = App::Lockd::Server::Resource->get(__LINE__);

    my $shared_lock1 = FakeLock->new( type => LOCK_SHARED );

    # one shared lock
    ok($r->lock($shared_lock1), 'lock shared');
    ok($r->is_locked, 'resource is locked');
    ok($shared_lock1->__was_signalled, 'Lock was signalled');
    ok($shared_lock1->__is_locked, 'lock signalled as locked');


    # Try getting excl lock - will be queued
    my $excl_lock = FakeLock->new( type => LOCK_EXCLUSIVE );
    ok($r->lock($excl_lock), 'add exclusive lock');
    ok(! $excl_lock->__was_signalled, 'excl lock was not signalled');


    # attach another shared lock
    my $shared_lock2 = FakeLock->new( type => LOCK_SHARED );
    ok($r->lock($shared_lock2), 'lock shared again');
    ok($shared_lock2->__was_signalled, 'Lock was signalled');
    ok($shared_lock2->__is_locked, 'lock signalled as locked');
    ok(! $excl_lock->__was_signalled, 'excl lock still was not signalled');


    # release the two shared locks
    ok($r->release($shared_lock1), 'release first shared lock');
    ok(! $excl_lock->__was_signalled, 'excl lock still was not signalled');
    ok($r->release($shared_lock2), 'release second shared lock');
    ok($excl_lock->__was_signalled, 'excl lock was signalled');
    ok($excl_lock->__is_locked, 'excl lock signalled as locked');
}

sub exclusive_then_shared {
    note('exclusive then shared');

    my $r = App::Lockd::Server::Resource->get(__LINE__);

    my $excl_lock1 = FakeLock->new( type => LOCK_EXCLUSIVE );
    ok($r->lock($excl_lock1), 'exclusive lock');
    ok($excl_lock1->__was_signalled, 'excl lock still was signalled');
    ok($excl_lock1->__is_locked, 'excl lock signalled as locked');
    

    my $shared_lock1 = FakeLock->new( type => LOCK_SHARED );
    my $shared_lock2 = FakeLock->new( type => LOCK_SHARED );
    my $excl_lock2 = FakeLock->new( type => LOCK_EXCLUSIVE );
    ok($r->lock($shared_lock1), 'add shared lock');
    ok(! $shared_lock1->__was_signalled, '... was not signalled');
    ok($r->lock($excl_lock2), 'add another exclusive lock');
    ok(! $excl_lock2->__was_signalled, '... was not signalled');
    ok($r->lock($shared_lock2), 'add another shared lock');
    ok(! $shared_lock2->__was_signalled, '... was not signalled');

    ok($r->release($excl_lock1), 'release first exclusive lock');
    foreach my $l ( $shared_lock1, $shared_lock2 ) {
        ok($l->__was_signalled, 'shared lock was signalled');
        ok($l->__is_locked, 'shared lock signalled as locked');
    }
    ok(! $excl_lock2->__was_signalled, 'second exclusive lock was not signalled');
}
