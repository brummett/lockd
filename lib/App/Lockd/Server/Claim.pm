package App::Lockd::Server::Claim;

use strict;
use warnings;

use App::Lockd::Util::HasProperties qw(resource type -nonew);
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

use Carp;

sub _new {
    my($class, $type, %params) = @_;

    Carp::croak('resource is a required parameter to create a Claim')
        unless (exists $params{resource});

    return bless { %params, type => $type }, $class;
}


sub shared {
    my $class = shift;
    return $class->_new(LOCK_SHARED, @_);
}

sub exclusive {
    my $class = shift;
    return $class->_new(LOCK_EXCLUSIVE, @_);
}


sub is_same_as {
    my($self, $other) = @_;
    return $self eq $other;
}

sub is_compatible_with {
    my($self, $other) = @_;
    return $self->type->is_compatible_with($other->type);
}

sub on_success {
    my($self, $code) = @_;
    if (my $orig = $self->{on_success}) {
        $self->{on_success} = sub {
            $orig->();
            $code->();
        };
    } else {
        $self->{on_success} = $code;
    }
}

sub signal {
    my $self = shift;
    my $code = delete $self->{on_success};
    $code->() if $code;
    return 1;
}

1;
