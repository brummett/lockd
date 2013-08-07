package App::Lockd::Server::Lock;

use strict;
use warnings;

use App::Lockd::Util::HasProperties qw(resource cb -nonew);
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

use Carp;

sub _new {
    my($class, $type, $resource) = @_;
    return bless { type => $type, resource => $resource }, $class;
}

sub type {
    my $self = shift;

    Carp::croak(q("type" is a read-only property)) if (@_);
    return $self->{type};
}

sub lock_shared {
    my($class, $resource) = @_;
    return $class->_new(LOCK_SHARED, $resource);
}

sub lock_exclusive {
    my($class, $resource) = @_;
    return $class->_new(LOCK_EXCLUSIVE, $resource);
}


sub then {
    my($self, $code) = @_;

    $self->cb($code);
    $self->resource->lock($self);
    return $self;
}

sub signal {
    my $self = shift;
    Carp::croak("$self has no callback set") unless ($self->cb);
    $self->cb->(@_);
}

sub unlock {
    my $self = shift;

    $self->resource->release($self);
}

sub is_same_as {
    my($self, $other) = @_;
    return $self eq $other;
}



1;
