package App::Lockd::Server::ConnectionBase;

# Base class for the different kinds of connections

use strict;
use warnings;

use App::Lockd::Util::HasProperties qw(fh watcher -nonew);
use AnyEvent::Handle;

sub new {
    my $class = shift;
    my %params = @_;

    my $self = bless \%params, $class;
    $self->_create_watcher();

    return $self;
}

sub additional_watcher_creation_params { (); };

sub _create_watcher {
    my($self) = @_;

    my @other_params = $self->additional_watcher_creation_params();

    my $w = AnyEvent::Handle->new(
        fh          => $self->fh,
        keepalive   => 1,
        on_eof      => sub { $self->on_eof(@_) },
        on_error    => sub { $self->on_error(@_) },
        @other_params,
    );

    $self->watcher($w);
}


sub push_read {
    my($self, $type, $sub) = @_;
    $self->watcher->push_read($type => $sub);
}

sub writemsg {
    my($self, $msg) = @_;

    $self->watcher->push_write($msg . "\r\n");
}

sub on_eof {
    # my($self, $watcher) = @_;
}

sub on_error {
    # my($self, $watcher, $is_fatal, $message) = @_;
}

sub on_read {
    # my($self, $watcher) = @_;
}

1;
