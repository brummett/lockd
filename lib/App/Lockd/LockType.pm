use strict;
use warnings;
use Carp;

package App::Lockd::LockType;

use constant UNLOCKED => 'App::Lockd::LockType::Unlocked';
use constant LOCK_SHARED => 'App::Lockd::LockType::Shared';
use constant LOCK_EXCLUSIVE => 'App::Lockd::LockType::Exclusive';

use base 'Exporter';
our @EXPORT_OK = qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

foreach my $required_method (qw( is_compatible_with upgraded_type downgraded_type ) ) {
    my $sub = sub {
        my $class = shift;
        Carp::croak("Class $class did not implement $required_method");
    };
    my $name = join('::', __PACKAGE__, $required_method);
    no strict 'refs';
    *$name = $sub;
}

1;

package App::Lockd::LockType::Unlocked;

our @ISA = qw(App::Lockd::LockType);

sub is_compatible_with { 1; }

sub upgraded_type { '' }
sub downgraded_type { '' }

package App::Lockd::LockType::Shared;

our @ISA = qw(App::Lockd::LockType);

sub is_compatible_with {
    my($self, $other) = @_;
    return $other->isa(App::Lockd::LockType::LOCK_EXCLUSIVE) ? 0 : 1;
}

sub upgraded_type { App::Lockd::LockType::LOCK_EXCLUSIVE }
sub downgraded_type { '' }

package App::Lockd::LockType::Exclusive;

our @ISA = qw(App::Lockd::LockType);

sub is_compatible_with {
    my($self, $other) = @_;
    return $other->isa(App::Lockd::LockType::UNLOCKED) ? 1 : 0;
}

sub upgraded_type { '' }
sub downgraded_type { App::Lockd::LockType::LOCK_SHARED }

1;
