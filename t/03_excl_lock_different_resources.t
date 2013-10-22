use strict;
use warnings;

use Test::More tests => 23;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

my $r = App::Lockd::Server::Resource->get(__FILE__);
ok($r, 'get first resource');

my $r2 = App::Lockd::Server::Resource->get(__FILE__ . $$);
ok($r2, 'get second resource');


my $first_lock_activated = 0;
my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);
my $success = App::Lockd::Server::Command::Lock->execute(
            resource => $r,
            claim => $excl,
            success => sub { $first_lock_activated++ }
        );
ok($success, 'Got exclusive lock for first resource');
is($first_lock_activated, 1, 'Lock was activated');

ok($r->is_holding($excl), 'Lock is holding resource');
ok(! $r->is_waiting($excl), 'Lock is not waiting on resource');


my $second_lock_activated = 0;
my $excl_2 = App::Lockd::Server::Claim->exclusive(resource => $r2);
$success = App::Lockd::Server::Command::Lock->execute(
            resource => $r2,
            claim => $excl_2,
            success => sub { $second_lock_activated++ }
        );

ok($success, 'Got second exclusive lock on second resource');
is($second_lock_activated, 1, 'Second lock was activated');

ok($r->is_holding($excl), 'Lock 1 is holding first resource');
ok(! $r->is_waiting($excl), 'Lock 1 is not waiting on first resource');
ok(! $r->is_holding($excl_2), 'Lock 2 is not holding first resource');
ok(! $r->is_waiting($excl_2), 'Lock 2 is not waiting on first resource');

ok(! $r2->is_holding($excl), 'Lock 1 is not holding second resource');
ok(! $r2->is_waiting($excl), 'Lock 1 is not waiting on second resource');
ok($r2->is_holding($excl_2), 'Lock 2 is holding second resource');
ok(! $r2->is_waiting($excl_2), 'Lock 2 is not waiting on second resource');

($first_lock_activated, $second_lock_activated) = (0,0);
$success = App::Lockd::Server::Command::Release->execute(claim => $excl);
ok($success, 'Unlock first lock');
is($first_lock_activated, 0, 'First lock was not activated');
is($second_lock_activated, 0, 'Second lock was activated');
ok(! $r->is_holding($excl), 'Lock 1 is not holding first resource');
ok(! $r->is_waiting($excl), 'Lock 1 is not waiting on first resource');
ok($r2->is_holding($excl_2), 'Lock 2 is holding second resource');
ok(! $r2->is_waiting($excl_2), 'Lock 2 is not waiting on second resource');


