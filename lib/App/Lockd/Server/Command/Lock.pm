package App::Lockd::Server::Command::Lock;

use strict;
use warnings;

use App::Lockd::Util qw(required_params);

use Promises;

sub execute {
    my $class = shift;

    my($resource, $claim, $success) = required_params([qw(resource claim success)], @_);

    # Don't double-lock the same lock
    return if $resource->is_claim_attached($claim);

    $claim->resource($resource);

    if ($resource->state->is_compatible_with($claim->type)) {
        $resource->state( $claim->type );
        $resource->add_to_holders( $claim );
        $success->();

    } else {
        $resource->add_to_waiters($claim);
        my $dfr = Promises::deferred;
        
        $claim->promise($dfr);
        $dfr->promise->then($success);
    }

    return 1;
}

1;
