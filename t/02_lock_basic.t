use strict;
use warnings;

use Test::More tests => 18;

use AnyEvent;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Lock;

my $r = App::Lockd::Server::Resource->get(__FILE__);
ok($r, 'get resource');

my $first_lock_activated = 0;
my $l = App::Lockd::Server::Lock->lock_exclusive($r)->then(
    sub { $first_lock_activated++ } );

ok($l, 'Got exclusive lock object');
ok($first_lock_activated, 'Lock was activated');

ok($r->is_holding($l), 'Lock is holding resource');
ok(! $r->is_waiting($l), 'Lock is not waiting on resource');


$first_lock_activated = 0;
my $second_lock_activated = 0;
my $l2 = App::Lockd::Server::Lock->lock_exclusive($r)->then(
    sub { $second_lock_activated++ } );

ok($l2, 'Got second exclusive lock');
is($second_lock_activated, 0, 'Second lock was not activated');

ok($r->is_holding($l), 'Lock 1 is holding resource');
ok(! $r->is_waiting($l), 'Lock 1 is not waiting on resource');
ok(! $r->is_holding($l2), 'Lock 2 is not holding resource');
ok($r->is_waiting($l2), 'Lock 2 is waiting on resource');


ok($l->unlock, 'Unlock first lock');
is($first_lock_activated, 0, 'First lock was not activated');
is($second_lock_activated, 1, 'Second lock was activated');
ok(! $r->is_holding($l), 'Lock 1 is not holding resource');
ok(! $r->is_waiting($l), 'Lock 1 is not waiting on resource');
ok($r->is_holding($l2), 'Lock 2 is holding resource');
ok(! $r->is_waiting($l2), 'Lock 2 is not waiting on resource');


