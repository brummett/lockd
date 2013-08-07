use strict;
use warnings;

use Test::More tests => 20;

use App::Lockd::Server::Lock;

ok(! eval { App::Lockd::Server::Lock->lock_shared() }, 'Creating lock without resource failed');
like($@, qr(Creating a lock requires a resource), 'Exception looks correct');

my $r = FakeResource->new;

for my $creation ( qw( lock_shared lock_exclusive) ) {
    my $l = App::Lockd::Server::Lock->$creation($r);
    ok($l, 'Create shared lock object');

    isa_ok($l->type, $creation eq 'lock_shared' ? 'App::Lockd::LockType::Shared' : 'App::Lockd::LockType::Exclusive');

    my $cb_triggered = 0;
    my @cb_args;
    ok($l->then( sub { @cb_args = @_; $cb_triggered = 1 } ), 'Assign callback');

    ok($l->signal(1,2,3), 'signal');
    is($cb_triggered, 1, 'callback was triggered');
    is_deeply(\@cb_args, [1,2,3], 'callback got its args');
}

my $shared = App::Lockd::Server::Lock->lock_shared($r);
my $excl = App::Lockd::Server::Lock->lock_exclusive($r);
ok($shared->is_same_as($shared), 'is same as');
ok(! $shared->is_same_as($excl), 'different locks are not the same');
ok(! $excl->is_same_as($shared), 'different locks are not the same both ways');

my $shared2 = App::Lockd::Server::Lock->lock_shared($r);
ok($shared->is_compatible_with($shared2), 'Shared locks are compatible with each other');
ok(! $shared->is_compatible_with($excl), 'Shared lock is not compatible with exclusive lock');
ok(! $excl->is_compatible_with($shared), 'Exclusive lock is not compatible with shared lock');


package FakeResource;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub lock {
    my $self = shift;
    $self->{lock} = 1;
}

sub release {
    my $self = shift;
    $self->{release} = 1;
}

sub value_for {
    my($self, $key) = @_;
    return $self->{$key};
}
