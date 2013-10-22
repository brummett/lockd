use strict;
use warnings;

use Test::More tests => 57;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

get();
one_claim_in_lists();
two_claims_in_lists();
add_multiple_claims_to_list();

sub get {
    my $r1 = App::Lockd::Server::Resource->get('bob');
    ok($r1, 'get resource named bob');
    my $r2 = App::Lockd::Server::Resource->get('bob');
    is($r1, $r2, 'Getting bob resource again returns the same object');

    is($r1->state, UNLOCKED, 'New resource state is unlocked');

    $r2 = App::Lockd::Server::Resource->get('joe');
    isnt($r1, $r2, 'Getting joe resource is different than bob resource');

    ok(! $r1->is_locked, 'New resource is not locked');
}

sub one_claim_in_lists {

    my $r1 = App::Lockd::Server::Resource->get(__LINE__);

    my $shared_lock1 = App::Lockd::Server::Claim->shared(resource => $r1);
    ok(! $r1->is_claim_attached($shared_lock1), 'is_claim_attached with new resource');

    ok($r1->add_to_holders($shared_lock1), 'Add shared lock to the holders list');
    ok(! $r1->add_to_holders($shared_lock1), 'cannot add the same lock to the list twice');
    ok($r1->is_locked, 'resource is locked');
    ok($r1->is_holding($shared_lock1), 'shared lock is holding the resource');
    ok($r1->is_claim_attached($shared_lock1), 'is_claim_attached after adding to list');


    ok($r1->remove_from_holders($shared_lock1), 'Remove shared lock from the holders list');
    ok(! $r1->is_locked, 'resource is now not locked');
    ok(! $r1->is_holding($shared_lock1), 'shared lock is not holding the resource');
    ok(! $r1->is_claim_attached($shared_lock1), 'is_claim_attached after removing from list');


    ok($r1->add_to_waiters($shared_lock1), 'Add shared lock to the waiters list');
    ok(! $r1->is_locked, 'resource is not locked');
    ok(! $r1->is_holding($shared_lock1), 'shared lock is not holding the resource');
    ok($r1->is_claim_attached($shared_lock1), 'is_claim_attached after adding to list');
}

sub two_claims_in_lists {
    my $r1 = App::Lockd::Server::Resource->get(__LINE__);
    my $shared_lock1 = App::Lockd::Server::Claim->shared(resource => $r1);
    my $excl_lock = App::Lockd::Server::Claim->exclusive(resource => $r1);

    ok($r1->add_to_holders($shared_lock1), 'Add shared claim to holders list');
    ok(! $r1->is_claim_attached($excl_lock), 'is_lock_attached for other excl lock');

    ok($r1->add_to_waiters($excl_lock), 'Add excl lock to the waiters list');
    ok($r1->is_claim_attached($shared_lock1), 'original shared lock is still attached');
    ok($r1->is_holding($shared_lock1), 'original shared lock is still holding the lock');
    ok(! $r1->is_waiting($shared_lock1), 'original shared lock is not waiting');
    ok($r1->is_claim_attached($excl_lock), 'excl lock still attached');
    ok(! $r1->is_holding($excl_lock), 'excl lock is not holding the lock');
    ok($r1->is_waiting($excl_lock), 'excl lock is waiting');


    # Add another shared lock
    my $shared_lock2 = App::Lockd::Server::Claim->shared(resource => $r1);
    ok(! $r1->is_claim_attached($shared_lock2), 'is_lock_attached for other shared lock');
    ok($r1->add_to_holders($shared_lock2), 'Add another shared lock to the holders list');


    foreach my $l ( $shared_lock1, $shared_lock2 ) {
        ok($r1->is_claim_attached($l), 'shared lock is attached');
        ok($r1->is_holding($l), 'shared lock is holding the lock');
        ok(! $r1->is_waiting($l), 'shared lock is not waiting');
    }
    ok($r1->is_claim_attached($excl_lock), 'excl lock still attached');
    ok(! $r1->is_holding($excl_lock), 'excl lock is not holding the lock');
    ok($r1->is_waiting($excl_lock), 'excl lock is waiting');


    # try removing from the wrong list
    ok(! $r1->remove_from_holders($excl_lock), 'cannot remove lock from the wrong list');
    ok(! $r1->remove_from_waiters($shared_lock1), 'cannot remove lock from the wrong list (again)');

    # and from the right list
    ok($r1->remove_from_holders($shared_lock1), 'Removed lock from the right list');
    ok(! $r1->is_holding($shared_lock1), 'removed lock is not in the holding list');
    ok(! $r1->is_waiting($shared_lock1), 'removed lock is not in the waiting list');
    ok(! $r1->is_claim_attached($shared_lock1), 'Shared claim is no longer attached');
    ok(! $r1->remove_from_holders($shared_lock1), 'cannot double-remove from the list');
    ok(! $r1->is_claim_attached($shared_lock1), '... and is still not attached');


    # remove the excl lock
    ok($r1->remove_from_waiters($excl_lock), 'Remove exclusive lock from waiters');
    ok(! $r1->is_claim_attached($excl_lock), 'excl lock is not attached');
    ok(! $r1->is_holding($excl_lock), 'excl lock is not holding');
    ok(! $r1->is_waiting($excl_lock), 'excl lock is not waiting');
}


sub add_multiple_claims_to_list {
    my $r1 = App::Lockd::Server::Resource->get(__LINE__);
    my $c1 = App::Lockd::Server::Claim->shared(resource => $r1);
    my $c2 = App::Lockd::Server::Claim->shared(resource => $r1);
    my $c3 = App::Lockd::Server::Claim->shared(resource => $r1);

    ok($r1->add_to_holders($c1), 'Add one item to the holders list');

    ok($r1->add_to_holders($c1, $c2, $c3), 'can multi-add when one item is already in the list');
    is($r1->is_locked, 3, '3 claims are holding the resource');
    foreach my $c ( $c1, $c2, $c3 ) {
        ok($r1->is_holding($c), 'resource is holding claim');
    }
}
