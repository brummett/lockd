use strict;
use warnings;

use Test::More tests => 55;

use App::Lockd::Server::Resource;
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

BEGIN { print "pwd is ",`pwd`,"\n"}
use lib 't/lib';
use FakeLock;

my $r1 = App::Lockd::Server::Resource->get('bob');
ok($r1, 'get resource named bob');
my $r2 = App::Lockd::Server::Resource->get('bob');
is($r1, $r2, 'Getting bob resource again returns the same object');

is($r1->state, UNLOCKED, 'New resource state is unlocked');

$r2 = App::Lockd::Server::Resource->get('joe');
isnt($r1, $r2, 'Getting joe resource is different than bob resource');

ok(! $r1->is_locked, 'New resource is not locked');

my $shared_lock1 = FakeLock->new( type => LOCK_SHARED );
ok(! $r1->is_lock_attached($shared_lock1), 'is_lock_attached with new resource');

# Lock with a shared lock
ok($r1->lock($shared_lock1), 'lock shared');
ok($r1->is_locked, 'resource is locked');
ok($r1->is_lock_attached($shared_lock1), 'is_lock_attached after locking');


my $excl_lock = FakeLock->new( type => LOCK_EXCLUSIVE );
ok(! $r1->is_lock_attached($excl_lock), 'is_lock_attached for other excl lock');


# Try locking with an excl lock - it's already shared locked
is($r1->state, LOCK_SHARED, 'Resource is in shared lock state');
ok($r1->lock($excl_lock), 'call lock() on resource with excl lock');


ok($r1->is_lock_attached($shared_lock1), 'original shared lock is still attached');
ok($r1->is_holding($shared_lock1), 'original shared lock is still holding the lock');
ok(! $r1->is_waiting($shared_lock1), 'original shared lock is not waiting');
ok($r1->is_lock_attached($excl_lock), 'excl lock still attached');
ok(! $r1->is_holding($excl_lock), 'excl lock is not holding the lock');
ok($r1->is_waiting($excl_lock), 'excl lock is waiting');


# Add another shared lock
my $shared_lock2 = FakeLock->new( type => LOCK_SHARED );
ok(! $r1->is_lock_attached($shared_lock2), 'is_lock_attached for other shared lock');
ok($r1->lock($shared_lock2), 'call lock() on resource with another shared lock');


foreach my $l ( $shared_lock1, $shared_lock2 ) {
    ok($r1->is_lock_attached($l), 'shared lock is attached');
    ok($r1->is_holding($l), 'shared lock is holding the lock');
    ok(! $r1->is_waiting($l), 'shared lock is not waiting');
}
ok($r1->is_lock_attached($excl_lock), 'excl lock still attached');
ok(! $r1->is_holding($excl_lock), 'excl lock is not holding the lock');
ok($r1->is_waiting($excl_lock), 'excl lock is waiting');


# release first shared lock
ok($r1->release($shared_lock1), 'release first shared lock');
ok(! $r1->is_lock_attached($shared_lock1), 'first shared lock is not attached');
ok(! $r1->is_holding($shared_lock1), 'first shared lock is not holding');
ok(! $r1->is_waiting($shared_lock1), 'first shared lock is not waiting');

ok($r1->is_lock_attached($shared_lock2), 'second shared lock is still attached');
ok($r1->is_holding($shared_lock2), 'second shared lock is holding');
ok(! $r1->is_waiting($shared_lock2), 'second shared lock is not waiting');

ok($r1->is_lock_attached($excl_lock), 'excl lock is still attached');
ok(! $r1->is_holding($excl_lock), 'excl lock is not holding');
ok($r1->is_waiting($excl_lock), 'sexcl lock is waiting');

is($r1->state, LOCK_SHARED, 'resource is lock_shared');

# release second shared lock
ok($r1->release($shared_lock2), 'Release second shared lock');
ok(! $r1->is_lock_attached($shared_lock2), 'second shared lock is not attached');
ok(! $r1->is_holding($shared_lock2), 'second shared lock is not holding');
ok(! $r1->is_waiting($shared_lock2), 'second shared lock is not waiting');

ok($r1->is_lock_attached($excl_lock), 'excl lock is still attached');
ok($r1->is_holding($excl_lock), 'excl lock is holding');
ok(! $r1->is_waiting($excl_lock), 'sexcl lock is not waiting');

is($r1->state, LOCK_EXCLUSIVE, 'resource is lock_exclusive');


# try releasing an already released lock
ok(! $r1->release($shared_lock1), 'releasing non-attached lock returns false');
ok(! $r1->is_lock_attached($shared_lock1), '... and is still not attached');


# release the excl lock
ok($r1->release($excl_lock), 'Release exclusive lock');
ok(! $r1->is_lock_attached($excl_lock), 'excl lock is not attached');
ok(! $r1->is_holding($excl_lock), 'excl lock is not holding');
ok(! $r1->is_waiting($excl_lock), 'excl lock is not waiting');

is($r1->state, UNLOCKED, 'resource is unlocked');
