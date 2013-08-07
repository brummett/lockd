use strict;
use warnings;

use Test::More tests => 23;

use AnyEvent;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Lock;

my $r = App::Lockd::Server::Resource->get(__FILE__);
ok($r, 'get first resource');

my $r2 = App::Lockd::Server::Resource->get(__FILE__ . $$);
ok($r2, 'get second resource');


my $first_lock_activated = 0;
my $l = App::Lockd::Server::Lock->lock_exclusive($r)->then(
    sub { $first_lock_activated++ } );

ok($l, 'Got exclusive lock object for first resource');
ok($first_lock_activated, 'Lock was activated');

ok($r->is_holding($l), 'Lock is holding resource');
ok(! $r->is_waiting($l), 'Lock is not waiting on resource');


$first_lock_activated = 0;
my $second_lock_activated = 0;
my $l2 = App::Lockd::Server::Lock->lock_exclusive($r2)->then(
    sub { $second_lock_activated++ } );

ok($l2, 'Got second exclusive lock on second resource');
is($second_lock_activated, 1, 'Second lock was activated');

ok($r->is_holding($l), 'Lock 1 is holding first resource');
ok(! $r->is_waiting($l), 'Lock 1 is not waiting on first resource');
ok(! $r->is_holding($l2), 'Lock 2 is not holding first resource');
ok(! $r->is_waiting($l2), 'Lock 2 is not waiting on first resource');

ok(! $r2->is_holding($l), 'Lock 1 is not holding second resource');
ok(! $r2->is_waiting($l), 'Lock 1 is not waiting on second resource');
ok($r2->is_holding($l2), 'Lock 2 is holding second resource');
ok(! $r2->is_waiting($l2), 'Lock 2 is not waiting on second resource');

($first_lock_activated, $second_lock_activated) = (0,0);
ok($l->unlock, 'Unlock first lock');
is($first_lock_activated, 0, 'First lock was not activated');
is($second_lock_activated, 0, 'Second lock was activated');
ok(! $r->is_holding($l), 'Lock 1 is not holding first resource');
ok(! $r->is_waiting($l), 'Lock 1 is not waiting on first resource');
ok($r2->is_holding($l2), 'Lock 2 is holding second resource');
ok(! $r2->is_waiting($l2), 'Lock 2 is not waiting on second resource');


