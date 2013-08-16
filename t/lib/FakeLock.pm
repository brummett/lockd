package FakeLock;

use App::Lockd::Server::Lock;

sub new {
    my($class, %params) = @_;
    return bless \%params, shift
};

sub is_same_as {
    return (shift eq shift);
}

sub type { return shift->{type} };

*is_compatible_with = \&App::Lockd::Server::Lock::is_compatible_with;

sub signal {
    my($self, $result) = @_;
    $self->{signal} = $result;
}

sub __was_signalled {
    return exists shift->{signal};
}

sub __is_locked {
    return shift->{signal};
}

1;
