use strict;
use warnings;

use Test::More tests => 33;

use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE UNLOCKED);
use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;

one_lock();

two_locks();

sub one_lock {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    ok($r, 'get resource');
    is($r->state, UNLOCKED, 'New resource is unlocked');

    my $c = App::Lockd::Server::Claim->exclusive;
    ok($c, 'Create exclusive claim');

    my $first_lock_activated = 0;
    my $success = App::Lockd::Server::Command::Lock->execute(
                resource => $r,
                claim => $c,
                success => sub { $first_lock_activated++ }
            );
    ok($success, 'Execute lock command');
    is($first_lock_activated, 1, 'Lock was activated');

    is($r->state, LOCK_EXCLUSIVE, 'resource is exclusive locked');
    ok($r->is_holding($c), 'Lock is holding resource');
    ok(! $r->is_waiting($c), 'Lock is not waiting on resource');
}

sub two_locks {

    my $r = App::Lockd::Server::Resource->get(__LINE__);
    ok($r, 'Get resource');

    my $c1 = App::Lockd::Server::Claim->exclusive;
    ok($c1, 'Create exclusive claim');
    
    my $c2 = App::Lockd::Server::Claim->exclusive;
    ok($c2, 'Create second exclusive claim');

    my $first_lock_activated = 0;
    my $success = App::Lockd::Server::Command::Lock->execute(
                resource => $r,
                claim => $c1,
                success => sub { $first_lock_activated++ }
            );
    ok($success, 'Execute lock command with first claim');
    is($first_lock_activated, 1, 'First lock was activated');
    is($r->state, LOCK_EXCLUSIVE, 'resource is exclusive locked');

    my $second_lock_activated = 0;
    $success = App::Lockd::Server::Command::Lock->execute(
                resource => $r,
                claim => $c2,
                success => sub { $second_lock_activated++ }
            );

    ok($success, 'Execute lock command with second claim');
    is($second_lock_activated, 0, 'Second lock was not activated');
    is($r->state, LOCK_EXCLUSIVE, 'resource is still exclusive locked');

    ok($r->is_holding($c1), 'Lock 1 is holding resource');
    ok(! $r->is_waiting($c1), 'Lock 1 is not waiting on resource');
    ok(! $r->is_holding($c2), 'Lock 2 is not holding resource');
    ok($r->is_waiting($c2), 'Lock 2 is waiting on resource');

    $success = App::Lockd::Server::Command::Release->execute( claim  => $c1 );
    ok($success, 'Unlock first lock');

    is($first_lock_activated, 1, 'First lock was not activated again');
    is($second_lock_activated, 1, 'Second lock was activated');
    ok(! $r->is_holding($c1), 'Lock 1 is not holding resource');
    ok(! $r->is_waiting($c1), 'Lock 1 is not waiting on resource');
    ok($r->is_holding($c2), 'Lock 2 is holding resource');
    ok(! $r->is_waiting($c2), 'Lock 2 is not waiting on resource');
    is($r->state, LOCK_EXCLUSIVE, 'resource is still exclusive locked');

    $success = App::Lockd::Server::Command::Release->execute( claim  => $c2 );
    ok($success, 'Unlock second lock');
    is($first_lock_activated, 1, 'First lock was not activated again');
    is($second_lock_activated, 1, 'Second lock was not activated again');

    is($r->state, UNLOCKED, 'resource is unlocked');
    
}

