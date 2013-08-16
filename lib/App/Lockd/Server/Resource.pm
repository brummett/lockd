package App::Lockd::Server::Resource;

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
}


sub lock {
    my($self, $lock) = @_;

    return if ($self->is_lock_attached($lock)); # Can't double-lock the same lock
    
    if ($self->state->is_compatible_with($lock->type)) {
        $self->_lock_aquired($lock);

    } else {
        $self->_add_to_list('waiters', $lock);
    }
}

sub release {
    my($self, $lock) = @_;

    if ($self->_is_in_list('holders', $lock)) {
        $self->_unlock($lock);

    } elsif ($self->_is_in_list('waiters', $lock)) {
        $self->_remove_from_list('waiters', $lock);

    } else {
        return;
    }
}

sub _unlock {
    my($self, $lock) = @_;

    $self->_remove_from_list('holders', $lock);

    my $holders = $self->holders;
    $self->_drain_waiters if (! @$holders);
    return 1;
}

# unlock() calls this when it's time for the next batch of locks to
# become active.  For example, after an exclusive lock is released,
# and the next lock is a shared lock, then all the shared locks can
# get signalled
#
# an alternative would be to shift off waiters as long as they're
# compatible with the first waiter
sub _drain_waiters {
    my $self = shift;

    my $waiters = $self->waiters;
    my $next = shift @$waiters;
    return unless $next;

    my @next = ( $next );
    for (my $i = 0; $i < @$waiters; $i++) {
        if ($next->is_compatible_with($waiters->[$i])) {
            push @next, splice(@$waiters, $i, 1);
            redo;
        }
    }

    $self->_lock_aquired($_) foreach @next;
}
    

sub _add_to_list {
    my($self, $listname, $lock) = @_;

    my $list = $self->$listname;
    push @$list, $lock;
}

sub _lock_aquired {
    my($self, $lock) = @_;

    $self->state( $lock->type );
    $self->_add_to_list('holders', $lock);
    $lock->signal(1);
}


# Return true if the lock is in the holders or waiters list
sub is_lock_attached {
    my($self, $lock) = @_;

    return $self->_is_in_list('holders', $lock) || $self->_is_in_list('waiters', $lock);
}

sub is_locked {
    my $self = shift;

    return scalar(@{$self->holders});
}

sub is_holding {
    my($self, $lock) = @_;
    return $self->_is_in_list('holders', $lock);
}

sub is_waiting {
    my($self, $lock) = @_;
    return $self->_is_in_list('waiters', $lock);
}

sub _is_in_list {
    my($self, $listname, $lock) = @_;

    my $list = $self->$listname;
    return any { $lock->is_same_as($_) } @$list;
}

sub _remove_from_list {
    my($self, $listname, $lock) = @_;

    my $list = $self->$listname;
    my $idx = first_index { $lock->is_same_as($_) } @$list;
    return $idx == -1 ? () : splice(@$list, $i, 1);
}

        
1;
