package App::Lockd::Server::Daemon;

use strict;
use warnings;

# The main code that handles connections to clients

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use App::Lockd::Util::HasProperties qw(stopper_cv _connections client_watcher cli_watcher -nonew);

use App::Lockd::Server::Daemon::Cli;
use App::Lockd::Server::Owner;

use constant CLIENT_LISTEN_PORT => 22334;
use constant CLI_LISTEN_PORT => 22335;

sub new {
    my $class = shift;

    my $self = bless {}, $class;

    $self->_connections({});
    return $self;
}

sub execute {
    my $self = shift;

    unless ($self->client_watcher) {
        my $client_watcher = AnyEvent::Socket::tcp_server(
                                    undef,
                                    CLIENT_LISTEN_PORT,
                                    sub { $self->new_client_connection(@_) }
                                );
        $self->client_watcher($client_watcher);
    }

#    my $cli_watcher = AnyEvent::Socket::tcp_server(
#                                undef,
#                                CLI_LISTEN_PORT,
#                                sub { $self->new_cli_connection(@_) }
#                            );
#    $self->cli_watcher($cli_watcher);

    print STDERR "Listening on port ",CLIENT_LISTEN_PORT," for connections\n";

    # Run the event loop
    $self->stopper_cv( AnyEvent->condvar )->recv;

    print STDERR "Exiting\n";
}

sub closed_connection {
    my($self, $conn) = @_;

    my $connections = $self->_connections;
    delete $connections->{$conn};
}

sub connections {
    my $self = shift;
    return values %{ $self->_connections };
}

sub new_client_connection {
    my($self, $sockfh, $host, $port) = @_;

    my $client = App::Lockd::Server::Owner->new(fh => $sockfh, daemon => $self, peerhost => $host, peerport => $port);
    my $connections = $self->_connections;
    $connections->{$client} = $client;
}

sub new_cli_connection {
    my($self, $sockfh, $host, $port) = @_;

    my $connections = $self->_connections;
    my $cli = App::Lockd::Server::Daemon::Cli->new(fh => $sockfh, daemon => $self, peerhost => $host, peerport => $port);
    $connections->{$cli} = $cli;
}



1;
