package App::Lockd::Server::Daemon::Cli;

use strict;
use warnings;

use base 'App::Lockd::Server::LineOrientedClient';

use Carp;

# Implements the command line interface

use App::Lockd::Util::HasProperties qw(fh watcher daemon -nonew);

sub new {
    my $class = shift;
    my %params = @_;

    Carp::croak("No fh") unless $params{fh};
    Carp::croak("No daemon") unless $params{daemon};

    my $self = $class->SUPER::new(%params);

    $self->announce;
    $self->queue_read;

    return $self;
}


sub readline {
    my($self, $w, $line) = @_;

    if ($line eq 'exit') {
        $self->daemon->closed_connection($self);
        close($self->fh);
        return;
    }
        
    $self->writemsg('unrecognized command');
    $self->queue_read;
}

sub on_eof {
    my($self, $w) = @_;

    my $fh = $self->fh;
    my($peer, $port) = map { $fh->$_ } qw(peerhost peerport);
    print STDERR "Client $peer:$port closed\n";
    $w->push_write("Goodbye\r\n");
    $fh->close();
}

sub on_error {
    my($self, $w, $is_fatal, $message) = @_;

    my $fh = $w->fh;
    my($peer, $port) = map { $fh->$_ } qw(peerhost peerport);
    print STDERR "Client $peer:$port had error $message\n";
    $fh->close();
}
    

sub announce {
    my $self = shift;

    $self->writemsg("Lockd console connected");
}


1;
