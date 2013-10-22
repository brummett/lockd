package App::Lockd::Server::Owner;

use strict;
use warnings;

# Represents the server's side of a connection talking to
# a client process.  This "owner" can own one or more Claims
# on Resources

use base 'App::Lockd::Server::ConnectionBase';

use App::Lockd::Util::HasProperties qw(locks daemon watcher peerhost peerport -nonew);

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;

use JSON;

use Carp;

sub new {
    my $class = shift;
    my %params = @_;

#    Carp::croak("no daemon") unless $params{daemon};
#    Carp::croak("no fh") unless $params{fh};

    my $self = $class->SUPER::new(%params);

    $self->locks({});

    return $self;
}

{
    my $json_codec;

    sub additional_watcher_creation_params {
        my $self = shift;

        $json_codec ||= JSON->new;
        return (
            json => $json_codec,
            on_read => sub {
                $self->watcher->unshift_read( json => sub { $self->on_read(@_) })
            },
        );
    }
}

sub on_eof {
    my $self = shift;

    $self->_clean_up_for_close();
}

# For now, on_error will get called even in the perfectly normal case where
# a client with no outstanding locks disconnects
sub on_error {
    my($self, $w, $is_fatal, $msg) = @_;

    if ($is_fatal) {
        $self->_clean_up_for_close();
    }
}


sub _clean_up_for_close {
    my $self = shift;

    $self->fh(undef);
    $self->watcher(undef);  # garbage collect everything the watcher is holding onto
    $self->daemon->closed_connection($self);
}


my $null_sub = sub {};

sub on_read {
    my($self, $watcher, $msg) = @_;

    my($on_success, $on_fail);
    $on_success = sub {
        ($on_success, $on_fail) = ($null_sub, $null_sub);
        $msg->{response} = 'OK';
        $self->watcher->push_write(json => $msg);
    };

    $on_fail = sub {
        my $reason = shift;
        ($on_success, $on_fail) = ($null_sub, $null_sub);
        $msg->{response} = $reason || $@;
        $self->watcher->push_write(json => $msg);
    };

    eval {
        my $cmd = $msg->{command};
        if ($cmd eq 'lock') {
            my($type, $key, $owner) = @$msg{'type','resource','owner'};
            ($type && $key && $owner)
                or die 'type, resource, and owner are all required properties to create a lock';

            if ($self->claim_for_key($key)) {
                die "resource $key is already claimed";
            }

            my $resource = App::Lockd::Server::Resource->get($key);
            $resource or die "cannot get resource $key";

            my $claim = App::Lockd::Server::Claim->$type(resource => $resource);
            $claim or die "cannot create $type claim";

            my $success = App::Lockd::Server::Command::Lock->execute(
                            resource => $resource,
                            claim    => $claim,
                            success  => sub {
                                            $self->accept_lock($resource, $claim)
                                                ? $on_success->()
                                                : $on_fail->('cannot accept lock');
                                        },
                        );
            $success or die "lock unsuccessful";

        } elsif ($cmd eq 'release') {
            exists($msg->{resource})
                or die "resource is a required property to release a lock";
            my $key = $msg->{'resource'};

            my $claim = $self->claim_for_key($key);
            $claim or die "key $key is not locked";
                
            $self->release($claim)
                ? $on_success->()
                : $on_fail->('cannot release lock');
        }
            
    };

    if ($@) {
        $on_fail->();
    }
}

sub accept_lock {
    my($self, $resource, $claim) = @_;

    my $locks = $self->locks;
    $locks->{ $resource->key } = $claim;
}


sub claim_for_key {
    my $self = shift;
    my $key = shift;

    my $locks = $self->locks;
    return $locks->{$key};
}

sub release {
    my($self, $claim) = @_;

    my $locks = $self->locks;
    my $resource = $claim->resource->key;
    delete($locks->{$resource});
    App::Lockd::Server::Command::Release->execute(claim => $claim);
}

sub DESTROY {
    # In the future when we're properly handling failover, we probably
    # want to turn this on - we shouldn't "properly" clean up held locks
    # if we're crashing
    #return if Devel::GlobalDestruction::in_global_destruction;

    my $self = shift;

    foreach my $claim ( values %{ $self->locks }) {
        $self->release($claim);
    }
}

1;
