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

    $self->queue_read;

    return $self;
}

{
    my $json_codec;

    sub additional_watcher_creation_params {
        $json_codec ||= JSON->new;
        return ( json => $json_codec );
    }
}

sub queue_read {
    my $self = shift;
    $self->watcher->push_read(json => sub { $self->on_read(@_); $self->queue_read(); })
}

sub on_read {
    my($self, $watcher, $msg) = @_;

    eval {
        my $cmd = $msg->{command};
        if ($cmd eq 'lock') {
            my($type, $key, $owner) = @$msg{'type','resource','owner'};
            ($type && $key && $owner)
                or die 'type, resource, and owner are all required properties to create a lock';

            my $resource = App::Lockd::Server::Resource->get($key);
            $resource or die "cannot get resource $key";

            my $claim = App::Lockd::Server::Claim->$type;
            $claim or die "cannot create $type claim";

            my $success = App::Lockd::Server::Command::Lock->execute(
                            resource => $resource,
                            claim    => $claim,
                            success  => sub { $self->accept_lock($resource, $claim) }
                        );
            $success or die "lock unsuccessful";

        } elsif ($cmd eq 'release') {
            exists($msg->{resource})
                or die "resource is a required property to release a lock";
            my $key = $msg->{'resource'};

            my $claim = $self->claim_for_key($key);
            $claim or die "key $key is not locked";
                
            $self->release($claim)
        }
            
    };

    $msg->{response} = $@ || 'OK';
    $self->watcher->push_write(json => $msg);
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

    App::Lockd::Server::Command::Release->execute(claim => $claim);
}

1;
