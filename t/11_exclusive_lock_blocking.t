use strict;
use warnings;

use Test::More tests => 33;

unless (defined &DB::DB) {
    $SIG{ALRM} = sub { ok(0,' Took too long'); exit(1); };
    alarm(10);
}

use App::Lockd::Server::Daemon;
use App::Lockd::Client;
use App::Lockd::Server::Resource;
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

use IO::Socket;

my $daemon = App::Lockd::Server::Daemon->new(
                client_watcher => 1,  # avoid creating a real one
            );

ok($daemon, 'Create server daemon');


shared_lock($daemon);
different_exclusive_locks($daemon);

same_exclusive_locks($daemon);

sub shared_lock {
    my $daemon = shift;

    my $client = make_connection_to_daemon($daemon);

    # Make a shared lock
    my $lock = $client->lock_shared('foo');
    ok($lock, 'Make shared lock');

    # Try making the same shared lock with the same client
    my $lock2 = eval { $client->lock_shared('foo') };
    ok(!$lock2, 'Cannot lock same resource with same client');
    like($@, qr(^Lock foo failed: resource foo is already claimed), 'Exception message');

    my @resource_keys = App::Lockd::Server::Resource->keys;
    is(scalar(@resource_keys), 1, 'One resource is known');
    is($resource_keys[0], 'foo', 'resource name');
    my $resource = App::Lockd::Server::Resource->get('foo');
    is($resource->state, LOCK_SHARED, 'is shared locked');

    ok($lock->release, 'Release shared lock');
    is($resource->state, UNLOCKED, 'underlying resource is unlocked');

    ok($client->close, 'Close client connection');
}



sub different_exclusive_locks {
    my $daemon = shift;

    my $client1 = make_connection_to_daemon($daemon);
    my $client2 = make_connection_to_daemon($daemon);

    my $lock1 = $client1->lock_exclusive('foo');
    ok($lock1, 'First exclusive lock');

    my $lock2 = $client2->lock_exclusive('bar');
    ok($lock2, 'Different exclusive lock');

    ok($lock1->release, 'release first lock');
    ok($lock2->release, 'release second lock');

    ok($client1->close, 'Close first client');
    ok($client2->close, 'Close second client');
}


sub same_exclusive_locks {
    my $daemon = shift;

    my $client1 = make_connection_to_daemon($daemon);
    my $client2 = make_connection_to_daemon($daemon);

    my $lock1 = $client1->lock_exclusive('foo');
    ok($lock1, 'First exclusive lock');

    my $cv = AnyEvent->condvar;
    my $lock2 = $client2->lock_exclusive('foo', $cv);
    is($lock2, 1, 'Second exclusive lock in non-blocking mode returns true');
    run_eventloop();
    ok(! $cv->ready, 'Second lock is blocking');

    ok($lock1->release, 'Release first lock');
    $lock2 = $cv->recv;
    ok($lock2, 'Second lock returns');
    isa_ok($lock2, 'App::Lockd::Client::Lock');

    ok($lock2->release, 'Release second lock');
}
    


sub run_eventloop {
    my $cv = AnyEvent->condvar;
    my $w = AnyEvent->idle(cb => $cv);
    $cv->recv;
}


sub make_connection_to_daemon {
    my $daemon = shift;

    my($server_sock, $client_sock) = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC);
    ok($daemon->new_client_connection($server_sock, 'lockhost', 'test'), 'Accept new connection');
    my $client = App::Lockd::Client->new(socket => $client_sock);
    ok($client, 'Create client connection');
    return $client;
}
