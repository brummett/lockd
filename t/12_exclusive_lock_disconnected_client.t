use strict;
use warnings;

use Test::More tests => 30;

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


same_exclusive_locks($daemon);
waiter_disconnects_before_getting_lock($daemon);


sub same_exclusive_locks {
    my $daemon = shift;

    note('same_exclusive_locks');

    my $client1 = make_connection_to_daemon($daemon);
    my $client2 = make_connection_to_daemon($daemon);

    my $lock1 = $client1->lock_exclusive('foo');
    ok($lock1, 'First exclusive lock');

    my $cv = AnyEvent->condvar;
    my $lock2 = $client2->lock_exclusive('foo', $cv);
    is($lock2, 1, 'Second exclusive lock in non-blocking mode returns true');
    run_eventloop();
    ok(! $cv->ready, 'Second lock is blocking');

    ok($client1->socket->close(), 'First client socket closes');
    $lock2 = $cv->recv;
    ok($lock2, 'Second lock returns');
    isa_ok($lock2, 'App::Lockd::Client::Lock');

    ok($lock2->release, 'Release second lock');
}

sub waiter_disconnects_before_getting_lock {
    my $daemon = shift;

    note('waiter_disconnects_before_getting_lock');

    my $client1 = make_connection_to_daemon($daemon);
    my $client2 = make_connection_to_daemon($daemon);
    my $client3 = make_connection_to_daemon($daemon);

    my $lock1 = $client1->lock_exclusive('foo');
    ok($lock1, 'First exclusive lock');

    my $resource = App::Lockd::Server::Resource->get('foo');
    is($resource->is_locked, 1, 'Resource foo has 1 locker');

    my $cv2 = AnyEvent->condvar;
    my $lock2 = $client2->lock_exclusive('foo', $cv2);
    is($lock2, 1, 'Second exclusive lock in non-blocking mode returns true');
    run_eventloop();

    is($resource->waiting_length, 1, 'Resource foo has 1 waiting');

    my $cv3 = AnyEvent->condvar;
    my $lock3 = $client3->lock_exclusive('foo', $cv3);
    is($lock3, 1, 'Third exclusive lock in non-blocking mode returns true');
    run_eventloop();
    is($resource->waiting_length, 2, 'Resource foo has 2 waiting');

    ok($client2->socket->close(), 'Second client closes while waiting');
    run_eventloop();

    is($resource->waiting_length, 1, 'Resource now has one waiter');

    ok($client1->socket->close(), 'First client closes while holding lock');
    $lock3 = $cv3->recv;
    ok($lock3, 'Third client has lock');
    isa_ok($lock3, 'App::Lockd::Client::Lock');

    ok($lock3->release, 'Release third lock');
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
