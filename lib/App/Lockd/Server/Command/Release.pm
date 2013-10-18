package App::Lockd::Server::Command::Release;

use strict;
use warnings;

use App::Lockd::LockType qw(UNLOCKED);
use App::Lockd::Util qw(required_params);

sub execute {
    my $class = shift;

    my($claim) = required_params([qw(claim)], @_);

    my $resource = $claim->resource;
    return unless $resource;

    # Search the is-holding list, since it's likely to be shorter
    # than is-waiting
    if ($resource->is_holding($claim)) {
        return unless $resource->remove_from_holders($claim);
    } else {
        return $resource->remove_from_waiters($claim);
    }
    $claim->resource(undef);

    unless ($resource->is_locked) {
        $resource->state(UNLOCKED);

        # drain all the compatible waiters
        my $waiters = $resource->waiters;
        my $next_claim = shift @$waiters;
        return 1 unless $next_claim;  # no more waiters either
        
        # Find all the waiters compatible with the next claim
        my @next = ($next_claim);
        push @next, $class->drain_waiters(claim => $next_claim);

        $resource->state( $next_claim->type );
        $resource->add_to_holders(@next);

        do { $_->signal } foreach @next;
    }

    return 1;
}

# Search through the waiters list on the resource and remove all claims that
# are compatible with the given claim to the holders list
#
# Returns the list of compatible claims
sub drain_waiters {
    my $class = shift;

    my($next_claim) = required_params([qw(claim)], @_);

    my $resource = $next_claim->resource;

    my @compatible;
    my $waiters = $resource->waiters;
    my $i = 0;
    while ($i < @$waiters) {
        if ($next_claim->is_compatible_with($waiters->[$i])) {
            push @compatible, splice(@$waiters, $i, 1);
        } else {
            $i++;
        }
    }

    return @compatible;
}


1;
