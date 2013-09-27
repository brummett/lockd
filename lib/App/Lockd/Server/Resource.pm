package App::Lockd::Server::Resource;

use strict;
use warnings;

# A named thing you can lock

use List::MoreUtils qw(any first_index);

use App::Lockd::Util::HasProperties qw(key state holders waiters -nonew);
use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

sub _new {
    my $class = shift;
    return App::Lockd::Util::HasProperties::new($class, @_);
}

{
    my %resources;
    sub get {
        my($class, $key) = @_;
        unless (exists $resources{$key}) {
            $resources{$key} = $class->_new(key => $key, state => UNLOCKED, holders => [], waiters => []);
        }
        return $resources{$key};
    }

    sub keys {
        return keys %resources;
    }
}


sub add_to_holders {
    my $self = shift;
    $self->_add_to_list('holders', @_);
}

sub add_to_waiters {
    my $self = shift;
    $self->_add_to_list('waiters', @_);
}

sub _add_to_list {
    my $self = shift;
    my $listname = shift;

    my $list = $self->$listname;
    my @added;
    foreach my $claim ( @_ ) {
        next if $self->_is_in_list($listname, $claim);
        push @$list, $claim;
        push @added, $claim;
    }
    return @added;
}


# Return true if the claim is in the holders or waiters list
sub is_claim_attached {
    my($self, $claim) = @_;

    return $self->_is_in_list('holders', $claim) || $self->_is_in_list('waiters', $claim);
}

sub is_locked {
    my $self = shift;

    return scalar(@{$self->holders});
}

sub is_holding {
    my($self, $claim) = @_;
    return $self->_is_in_list('holders', $claim);
}

sub is_waiting {
    my($self, $claim) = @_;
    return $self->_is_in_list('waiters', $claim);
}

sub waiting_length {
    my $self = shift;
    return scalar(@{ $self->waiters });
}

sub _is_in_list {
    my($self, $listname, $claim) = @_;

    my $list = $self->$listname;
    return any { $claim->is_same_as($_) } @$list;
}

sub remove_from_holders {
    my $self = shift;
    $self->_remove_from_list('holders', @_);
}

sub remove_from_waiters {
    my $self = shift;
    $self->_remove_from_list('waiters', @_);
}

sub _remove_from_list {
    my($self, $listname, $claim) = @_;

    my $list = $self->$listname;
    my $idx = first_index { $claim->is_same_as($_) } @$list;
    return $idx == -1 ? () : splice(@$list, $idx, 1);
}

        
1;
