use strict;
use warnings;

use Test::More tests => 15;

use App::Lockd::LockType qw(UNLOCKED LOCK_SHARED LOCK_EXCLUSIVE);

# UNLOCKED is compatible with everything else
foreach my $other (UNLOCKED,  LOCK_SHARED, LOCK_EXCLUSIVE) {
    ok(UNLOCKED->is_compatible_with($other), "unlocked is compatible with $other");
}

# shared is compatible with unlocked and shared
foreach my $other (UNLOCKED, LOCK_SHARED) {
    ok(LOCK_SHARED->is_compatible_with($other), "shared is compatible with $other");
}
ok(! LOCK_SHARED->is_compatible_with(LOCK_EXCLUSIVE), 'shared is not compatible with exclusive');


# exclusive is only compatible with unlocked
ok(LOCK_EXCLUSIVE->is_compatible_with(UNLOCKED), 'exclusive is compatible with unlocked');
foreach my $other (LOCK_SHARED, LOCK_EXCLUSIVE) {
    ok(! LOCK_EXCLUSIVE->is_compatible_with($other), "exclusive is not compatible with $other");
}
    

ok(! UNLOCKED->upgraded_type, 'unlocked has no upgraded type');
ok(! UNLOCKED->downgraded_type, 'unlocked has no downgraded type');

ok(! LOCK_EXCLUSIVE->upgraded_type, 'exclusive has no upgraded type');
is(LOCK_EXCLUSIVE->downgraded_type, LOCK_SHARED, 'exclusive downgraded type is shared');

ok(! LOCK_SHARED->downgraded_type, 'shared has no downgraded type');
is(LOCK_SHARED->upgraded_type, LOCK_EXCLUSIVE, 'shared upgraded type is exclusive');
