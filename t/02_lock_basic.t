use strict;
use warnings;

use Test::More tests => 5;

use AnyEvent;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Lock;

my $r = App::Lockd::Server::Resource->get(__FILE__);
ok($r, 'get resource');

my $lock_activated = 0;
my $l = App::Lockd::Server::Lock->lock_exclusive($r)->then(
    sub {
        $lock_activated = shift;
    });

ok($l, 'Got exclusive lock object');
ok($lock_activated, 'Lock was activated');

ok($r->is_holding($l), 'Lock is holding resource');
ok(! $r->is_waiting($l), 'Lock is not waiting on resource');

