package App::Lockd::Server::Command::UpgradeLock;

use strict;
use warnings;

use Carp;

use App::Lockd::Util qw(required_params);

use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

sub execute {
    my $class = shift;

    my($claim, $success) = required_params([qw(claim success)], @_);

    my $upgraded_type = $claim->type->upgraded_type;
    $upgraded_type or return;

    my $resource = $claim->resource;

    if ($resource->is_waiting($claim)) {
        # just go ahead and change the type of the lock
        $claim->type( $upgraded_type );
        $success->();
        return 1;
    }

    $resource->is_holding($claim) or return;

    if ($resource->is_locked == 1
        or
        $resource->state->is_compatible_with($upgraded_type)
    ) {
        # no other holders, just change the type of the lock
        # and state of the resource
        $claim->type( $upgraded_type );
        $resource->state( $upgraded_type );
        $success->();
        return 1;
    }

    # No easy transisition - we'll have to unlock the current lock and
    # queue it up
    App::Lockd::Server::Command::Release->execute( claim => $claim)
        or Carp::croak('Could not release claim on resource');

    # The Release command sets the claim's resource to undef
    $claim->resource($resource);
    $claim->type( $upgraded_type );
    App::Lockd::Server::Command::Lock->execute(
        claim => $claim,
        success => $success
    ) or Carp::croak('Could not re-add claim to resource after releasing it');

    return 0;
}

    
1;
