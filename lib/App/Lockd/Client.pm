package App::Lockd::Client;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use Carp;
use JSON;
use Sys::Hostname qw();
use Time::HiRes qw(time);

use App::Lockd::Util::HasProperties qw(socket watcher host port hostname -nonew);

use App::Lockd::Client::Lock;

sub new {
    my $class = shift;
    my %params = @_;

    if (! $params{socket}) {
        foreach my $param ( qw( host port ) ) {
            $params{$param} || Carp::croak("$param is a required parameter to App::Lockd::Client->new");
        }
    }

    my $self = bless \%params, $class;

    $self->socket || $self->_open_socket() || return;

    $self->_create_watcher;

    $self->hostname( Sys::Hostname::hostname );

    return $self;
}

sub _open_socket {
    my $self = shift;
    
    return 1 if ($self->socket);

    my $cv = AnyEvent->condvar;
    AnyEvent::Socket::tcp_connect(
        $self->host, $self->port,
        sub {
            $cv->send(shift);  # gets the handle as the arg
        }
    );

    my $socket = $cv->recv;
    $self->socket($socket);
    $self->on_connect();
    return $socket;
}

sub on_error {
    my($self, $watcher, $is_fatal, $msg) = @_;
    Carp::croak("Error on lock socket: $msg");
}

sub on_eof {
    my($self, $watcher) = @_;
    Carp::croak("Unexpected EOF on lock socket");
}

sub _create_watcher {
    my $self = shift;

    my $socket = $self->socket;
    my $watcher = AnyEvent::Handle->new(
                    fh => $socket,
                    on_error => sub { $self->on_error(@_) },
                    on_eof => sub { $self->on_eof(@_) },
                    keepalive => 1,
                    json => JSON->new,
                );
    $watcher || Carp::croak("Cannot create watcher");
    $self->watcher($watcher);
}


sub _basic_msg {
    my $self = shift;
    return (
        owner => sprintf('%d on %s', $$, $self->hostname),
        time => time(),
    );
}

sub lock_shared {
    my($self, $resource) = @_;

    $resource || Carp::croak("resource is a required parameter to lock_shared");
    return $self->_lock_('shared', $resource);
}

sub lock_exclusive {
    my($self, $resource) = @_;

    $resource || Carp::croak("resource is a required parameter to lock_exclusive");
    return $self->_lock_('exclusive', $resource);
}


sub _send_request {
    my($self, $msg) = @_;
    $self->watcher->push_write( json => $msg );
}

sub _wait_for_response {
    my $self = shift;

    my $cv = AnyEvent->condvar;
    $self->watcher->push_read(json => sub {
        my($w, $data) = @_;
        $cv->send($data);
    });
    return $cv->recv;
}

sub _lock_ {
    my($self, $type, $resource) = @_;

    my $msg = {
            $self->_basic_msg,
            command => 'lock',
            type    => $type,
            resource => $resource,
        };

    $self->_send_request( $msg );

    my $data = $self->_wait_for_response;

    if ($data->{response} ne 'OK') {
        Carp::croak("Lock $resource failed: ".$data->{response});
    }

    my $release = $self->_make_release_closure($msg);

    return App::Lockd::Client::Lock->new($type, $resource, $release);
}

sub _make_release_closure {
    my($self, $msg) = @_;

    my %release_msg = %$msg;
    $release_msg{command} = 'release';
    $release_msg{time} = time();

    return sub {
        $self->_send_request(\%release_msg);
        my $data = $self->_wait_for_response();
        if ($data->{response} ne 'OK') {
            Carp::croak("Release $release_msg{resource} failed: ".$data->{response});
        }
        return 1;
    };
}



sub on_connect { }

1;
