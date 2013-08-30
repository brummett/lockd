package App::Lockd::Server::LineOrientedClient;

use strict;
use warnings;

use AnyEvent::Handle;

sub _create_watcher {
    my($self, $fh) = @_;

    my $w = AnyEvent::Handle->new(
        fh          => $self->fh,
        keepalive   => 1,
        on_eof      => sub { $self->on_eof(@_) },
        on_error    => sub { $self->on_error(@_) },
    );

    $self->watcher($w);
}


sub queue_read {
    my $self = shift;
    $self->watcher->push_read(line => sub { $self->readline(@_) });
}

sub writemsg {
    my($self, $msg) = @_;

    $self->watcher->push_write($msg . "\r\n");
}


1;
