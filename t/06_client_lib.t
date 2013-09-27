use strict;
use warnings;

use Test::More tests => 42;

$SIG{ALRM} = sub { ok(0,' Took too long'); exit(1); };
alarm(10);

use App::Lockd::Client;
use Sys::Hostname qw();
use AnyEvent;

use File::Basename;
use lib File::Basename::dirname(__FILE__).'/lib';
use AnyEventHandleFake;

bad_construction_params();
new_with_host_and_port();
new_with_socket();
lock_then_unlock();

sub bad_construction_params {
    ok(! eval { ClientTest->new() },
        'Cannot create Client object with no params');
    like($@,
        qr(host is a required parameter),
        'exception message');

    ok(! eval { ClientTest->new(host => 'foo') },
        'Cannot create Client object with only host param');
    like($@,
        qr(port is a required parameter),
        'exception message');

    ok(! eval { ClientTest->new(port => 'bar') }, 
        'Cannot create Client object with only host param');
    like($@,
        qr(host is a required parameter),
        'exception message');
}

sub new_with_host_and_port {
    my $cv = AnyEvent->condvar;
    my $client = ClientTest->new(host => 'foo', port => 'bar', cv => $cv);
    my $result = $cv->recv;
    is_deeply($result,
        ['_open_socket', host => 'foo', port => 'bar'],
        'Instantiate Client with host and calls _open_socket');
}

sub new_with_socket {
    my $cv = AnyEvent->condvar;
    my $client = ClientTest->new(socket => 'foo', cv => $cv);
    my $result = $cv->recv;
    is_deeply($result,
        ['_create_watcher'],
        'Instantiate Client with socket calls _create_watcher');
}

sub lock_then_unlock {
    foreach my $lock_type ( qw(shared exclusive) ) {
        my $client = ClientTest->new(socket => 'foo');
        my $watcher = $client->watcher;

        $watcher->_queue_input({ response => 'OK'});
        my $lock_method = "lock_$lock_type";
        my $lock = $client->$lock_method('bob');

        isa_ok($lock, 'App::Lockd::Client::Lock');
        is($lock->resource, 'bob', 'lock resource');
        is($lock->type, $lock_type, 'lock type');

        my $sent_msgs = $watcher->_written_data;
        is(scalar(@$sent_msgs), 1, 'one message sent');
        is($sent_msgs->[0]->{owner}, expected_owner(), 'sent message owner');
        like($sent_msgs->[0]->{time}, qr(^\d+\.\d+$), 'sent message time');
        is($sent_msgs->[0]->{command}, 'lock', 'sent message command');
        is($sent_msgs->[0]->{type}, $lock_type, 'sent message type');
        is($sent_msgs->[0]->{resource}, 'bob', 'sent message resource');

        $watcher->_queue_input({ response => 'OK'});
        ok($lock->release, 'release lock');
        my $sent_msgs2 = $watcher->_written_data;

        is(scalar(@$sent_msgs2), 1, 'one message sent');
        is($sent_msgs2->[0]->{owner}, expected_owner(), 'sent message owner');
        like($sent_msgs2->[0]->{time}, qr(^\d+\.\d+$), 'sent message time');
        isnt($sent_msgs2->[0]->{time},
             $sent_msgs->[0]->{time},
             'Second message time is different than first msg time');
        is($sent_msgs2->[0]->{command}, 'release', 'sent message command');
        is($sent_msgs2->[0]->{type}, $lock_type, 'sent message type');
        is($sent_msgs2->[0]->{resource}, 'bob', 'sent message resource');
    }
}



sub expected_owner {
    return sprintf('%d on %s', $$, Sys::Hostname::hostname);
}



sub does_not_block {
    my($code, $msg) = @_;

    my $a = 1;
    my $ref = \$a;
    local $SIG{ALRM} = sub { die $ref };
    alarm(1);
    my $result = eval { $code->() };
    alarm(0);
    if ($@ and $@ eq $ref) {
        ok(0, $msg . ' - blocked');
    }
    return $result;
}


package ClientTest;
use IO::Socket;

use App::Lockd::Client;
BEGIN {
    our @ISA = qw(App::Lockd::Client);
}

sub cv {
    my $self = shift;
    if (@_) {
        $self->{cv} = shift;
    }
    return $self->{cv};
}

sub _open_socket {
    my $self = shift;

    return unless $self->cv;
    $self->cv->send(['_open_socket', host => $self->host, port => $self->port]);
}

sub _create_watcher {
    my $self = shift;
    if ($self->cv) {
        $self->cv->send(['_create_watcher']);
    }
    return $self->watcher(AnyEventHandleFake->new());
}

