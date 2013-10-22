package App::Lockd::Server::Command::DowngradeLock;

use strict;
use warnings;

use Carp;

use App::Lockd::Util qw(required_params);

use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

sub execute {
    my $class = shift;

    my($claim, $success) = required_params([qw(claim success)], @_);

    my $downgraded_type = $claim->type->downgraded_type;
    $downgraded_type or return;

    my $resource = $claim->resource;

    if ($resource->is_waiting($claim)) {
        # This claim doesn't hold the resource.
        # just go ahead and change the type of the lock
        $claim->type( $downgraded_type );

        # If the new type is compatible with the resource's state,
        # then it can also claim the resource
        if ($resource->state->is_compatible_with( $downgraded_type )) {
            $resource->remove_from_waiters($claim);
            $resource->add_to_holders($claim);
            $claim->signal;
        }
        $success->();
        return 1;
    }

    # The claim must be holding the resource

    if ($resource->is_locked == 1) {
        # no other holders, just change the type of the lock
        # and state of the resource
        $claim->type( $downgraded_type );
        $resource->state( $downgraded_type );

        # Find any other waiting locks that are compatible
        if (my @others = App::Lockd::Server::Command::Release->drain_waiters(claim => $claim) ) {
            $resource->add_to_holders(@others);
            do { $_->signal } foreach @others;
        }

        $success->();
        return 1;
    }

    # No easy transisition - we'll have to unlock the current lock and
    # queue it up
    App::Lockd::Server::Command::Release->execute( claim => $claim)
        or Carp::croak('Could not release claim on resource');
    $claim->type( $downgraded_type );
    App::Lockd::Server::Command::Lock->execute(
        claim => $claim,
        success => $success
    ) or Carp::croak('Could not re-add claim to resource after releasing it');

    return 0;
}

    
1;
