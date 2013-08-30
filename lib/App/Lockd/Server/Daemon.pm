package App::Lockd::Server::Daemon;

use strict;
use warnings;

# The main code that handles connections to clients

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use App::Lockd::Util::HasProperties qw(stopper_cv connections client_watcher cli_watcher);

use App::Lockd::Server::Daemon::Cli;

use constant CLIENT_LISTEN_PORT => 22334;
use constant CLI_LISTEN_PORT => 22335;

sub execute {
    my $self = shift;

    $self->connections({});

    my $client_watcher = AnyEvent::Socket::tcp_server(
                                undef,
                                CLIENT_LISTEN_PORT,
                                sub { $self->new_client_connection(@_) }
                            );
    $self->client_watcher($client_watcher);

    my $cli_watcher = AnyEvent::Socket::tcp_server(
                                undef,
                                CLI_LISTEN_PORT,
                                sub { $self->new_cli_connection(@_) }
                            );
    $self->cli_watcher($cli_watcher);

    print STDERR "Listening on port ",CLIENT_LISTEN_PORT," for connections\n";

    # Run the event loop
    $self->stopper_cv( AnyEvent->condvar )->recv;

    print STDERR "Exiting\n";
}

sub closed_connection {
    my($self, $conn) = @_;

    my $connections = $self->connections;
    delete $connections->{$conn};
}

sub new_cli_connection {
    my($self, $sockfh, $host, $port) = @_;

    my $connections = $self->connections;
    my $cli = App::Lockd::Server::Daemon::Cli->new(fh => $sockfh, daemon => $self);
    $connections->{$cli} = $cli;
}

1;
