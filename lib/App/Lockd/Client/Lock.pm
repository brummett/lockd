package App::Lockd::Client::Lock;

sub new {
    my($class, $type, $resource, $release) = @_;

    my $self = {
        type        => $type,
        resource    => $resource,
        release      => $release,
    };

    return bless $self, $class;
}

sub type {
    return shift->{type};
}

sub resource {
    return shift->{resource};
}

sub release {
    my $self = shift;
    my $release = $self->{release};

    $self->{release} = sub {};

    $release->();
}

sub DESTROY {
    shift->release;
}

1;
