use strict;
use warnings;

use Test::More tests => 16;

use App::Lockd::Server::Daemon;
use App::Lockd::Client;

use IO::Socket;
use AnyEvent;

my $daemon = App::Lockd::Server::Daemon->new(
                client_watcher => 1,  # avoid creating a real one
            );

ok($daemon, 'Create server daemon');

my @clients;
for( my $i = 1; $i < 4; $i++) {
    my $client = make_connection_to_daemon($daemon);
    push @clients, $client;
    is(scalar( $daemon->connections ), $i, "$i connections to the daemon");
}

while(my $client = shift @clients) {
    ok($client->socket->close(), 'Close a connection');
    my $cv = AnyEvent->condvar;
    my $w = AnyEvent->idle(cb => $cv);
    $cv->recv;
    my $expected = scalar(@clients);
    is(scalar( $daemon->connections ), $expected, "$expected connections to the daemon");
}




sub make_connection_to_daemon {
    my $daemon = shift;

    my($server_sock, $client_sock) = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC);
    ok($daemon->new_client_connection($server_sock, 'lockhost', 'test'), 'Accept new connection');
    my $client = App::Lockd::Client->new(socket => $client_sock);
    ok($client, 'Create client connection');
    return $client;
}
