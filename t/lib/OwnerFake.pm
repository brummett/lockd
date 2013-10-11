package OwnerFake;

use App::Lockd::Server::Owner;
BEGIN {
    our @ISA = qw(App::Lockd::Server::Owner);
}

sub cv {
    my $self = shift;
    if (@_) {
        $self->{cv} = shift;
    }
    return $self->{cv};
}

sub _create_watcher {
    my $self = shift;
    if ($self->cv) {
        $self->cv->send(['_create_watcher']);
    }
    my @watcher_args = $self->additional_watcher_creation_params();
    return $self->watcher(AnyEventHandleFake->new(@watcher_args));
}

1;
