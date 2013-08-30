package App::Lockd::Server::Daemon::Cli;

use strict;
use warnings;

# Implements the command line interface

use App::Lockd::Util::HasProperties qw(fh watcher daemon);

sub run {
    my $self = shift;

    die "No fh" unless $self->fh;
    die "No daemon" unless $self->daemon;

    my $watcher = AnyEvent::Handle->new(
                        fh          => $self->fh,
                        keepalive   => 1,
                        on_eof      => sub { $self->on_eof(@_) },
                        on_error    => sub { $self->on_error(@_) },
                    );
    $self->watcher($watcher);

    $self->announce;
    $self->queue_read;
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
    

sub queue_read {
    my $self = shift;
    $self->watcher->push_read(line => sub { $self->readline(@_) });
}
    



sub writemsg {
    my($self, $msg) = @_;

    $self->watcher->push_write($msg . "\r\n");
}

sub announce {
    my $self = shift;

    $self->writemsg("Lockd console connected");
}


1;
