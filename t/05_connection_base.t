use strict;
use warnings;

use Test::More tests => 17;

basic_connection();
on_error();

sub basic_connection {
    my $cv = AnyEvent->condvar;
    my $conn = ConnectionBaseTest->new(cv => $cv);
    ok($conn, 'Create Connection object');

    ok( $conn->print_to("Hello\n"), 'Send message\n');
    my $result = does_not_block(sub { $cv->recv() }, 'process message');

    is(@$result, 2, 'Got back items');
    is($result->[0], 'on_read', 'on_read() called on connection');
    is($result->[1], "Hello\n", 'Message is readline() second arg');


    $cv = AnyEvent->condvar;
    $conn->cv($cv);
    ok($conn->close, 'Close connection');
    $result = does_not_block(sub { $cv->recv() }, 'process close state');

    is(@$result, 2, 'Got back items');
    is($result->[0], 'on_eof', 'on_eof called on connection');
    is($result->[1], $conn->watcher, 'connection watcher second arg');
}


sub on_error {
    my $cv = AnyEvent->condvar;
    my $conn = ConnectionBaseTest->new(cv => $cv);
    ok($conn, 'Create another connection object');

    ok($conn->push_read(line => sub { ok(0, 'some data was read'); }),
        'Queue a read');
    ok($conn->close, 'Close connection');

    my $result = does_not_block(sub { $cv->recv }, 'process unexpected close');
    is(@$result, 4, 'Got back items');
    is($result->[0], 'on_error', 'on_error called on connection');
    isa_ok($result->[1],'AnyEvent::Handle::destroyed');
    is($result->[2], 1, 'is_fatal flag set');
    is($result->[3], 'Broken pipe', 'Error message');
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


package ConnectionBaseTest;
use IO::Socket;

use App::Lockd::Server::ConnectionBase;
BEGIN {
    our @ISA = qw(App::Lockd::Server::ConnectionBase);
}

sub new {
    my $class = shift;
    my @socks = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC);
    my $self = $class->SUPER::new(fh => $socks[0], print_to => $socks[1], @_);
    return $self;
}

sub additional_watcher_creation_params {
    my $self = shift;
    ( on_read => sub { $self->on_read(@_) } );
}

sub print_to {
    my $self = shift;
    $self->{print_to}->printflush(@_);
}

sub close {
    my $self = shift;
    $self->{print_to}->close();
}

sub cv {
    my $self = shift;
    if (@_) {
        $self->{cv} = shift;
    }
    return $self->{cv};
}

sub on_eof {
    my $self = shift;
    $self->cv->send(['on_eof', @_]);
}

sub on_error {
    my $self = shift;
    $self->cv->send(['on_error', @_]);
}

sub on_read {
    my($self, $watcher) = @_;
    my $message = $watcher->{rbuf};
    $watcher->{rbuf} = '';
    $self->cv->send(['on_read', $message]);
}

