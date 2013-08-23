package App::Lockd::Server::Claim;

use strict;
use warnings;

use App::Lockd::Util::HasProperties qw(resource on_success -nonew);
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

use Carp;

sub _new {
    my($class, $type) = @_;
    return bless { type => $type }, $class;
}

sub type {
    my $self = shift;

    Carp::croak(q("type" is a read-only property)) if (@_);
    return $self->{type};
}

sub shared {
    my($class) = @_;
    return $class->_new(LOCK_SHARED);
}

sub exclusive {
    my($class) = @_;
    return $class->_new(LOCK_EXCLUSIVE);
}


sub is_same_as {
    my($self, $other) = @_;
    return $self eq $other;
}

sub is_compatible_with {
    my($self, $other) = @_;
    return $self->type->is_compatible_with($other->type);
}



1;
