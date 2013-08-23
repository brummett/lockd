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

    return unless $resource->remove_from_holders($claim);

    unless ($resource->is_locked) {
        $resource->state(UNLOCKED);

        # drain all the compatible waiters
        my $waiters = $resource->waiters;
        my $next_claim = shift @$waiters;
        return 1 unless $next_claim;  # no more waiters either
        
        # Find all the waiters compatible with the next claim
        my @next = ( $next_claim );
        my $i = 0;
        while ($i < @$waiters) {
            if ($next_claim->is_compatible_with($waiters->[$i])) {
                push @next, splice(@$waiters, $i, 1);
            } else {
                $i++;
            }
        }

        $resource->state( $next_claim->type );
        $resource->add_to_holders(@next);

        do { $_->on_success->($resource) } foreach @next;
    }

    return 1;
}

1;
