use strict;
use warnings;

use Test::More tests => 14;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

my $r = App::Lockd::Server::Resource->get(__FILE__);
ok($r, 'get resource');


my $first_lock_activated = 0;
my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);
my $success = App::Lockd::Server::Command::Lock->execute(
            claim => $excl,
            success => sub { $first_lock_activated++ }
        );
ok($success, 'Got exclusive lock');
is($first_lock_activated, 1, 'Lock was activated');

ok($r->is_holding($excl), 'Lock is holding resource');
ok(! $r->is_waiting($excl), 'Lock is not waiting on resource');


my $second_lock_activated = 0;
my $excl_2 = App::Lockd::Server::Claim->exclusive(resource => $r);
$success = App::Lockd::Server::Command::Lock->execute(
            claim => $excl_2,
            success => sub { $second_lock_activated++ }
        );

ok($success, 'Got second exclusive lock on second resource');
is($second_lock_activated, 0, 'Second lock was not yet activated');

($first_lock_activated, $second_lock_activated) = (0,0);
$success = App::Lockd::Server::Command::Release->execute(claim => $excl_2);
ok($success, 'release second (waiting) lock');
is($first_lock_activated, 0, 'First lock was not activated');
is($second_lock_activated, 0, 'Second lock was not activated');
ok($r->is_holding($excl), 'Lock 1 is still holding resource');
ok(! $r->is_waiting($excl), 'Lock 1 is not waiting on resource');
ok(! $r->is_holding($excl_2), 'Lock 2 is not holding resource');
ok(! $r->is_waiting($excl_2), 'Lock 2 is not waiting on resource');


