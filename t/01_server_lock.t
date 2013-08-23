use strict;
use warnings;

use Test::More tests => 10;

use App::Lockd::Server::Claim;
use App::Lockd::LockType qw(LOCK_SHARED LOCK_EXCLUSIVE);

create();
same();
compatible();


sub create {
    my $shared = App::Lockd::Server::Claim->shared;
    ok($shared, 'Create shared claim object');
    isa_ok($shared->type, LOCK_SHARED);

    my $excl = App::Lockd::Server::Claim->exclusive;
    ok($excl, 'Create exclusive claim object');
    isa_ok($excl->type, LOCK_EXCLUSIVE);
}

sub same {
    my $shared = App::Lockd::Server::Claim->shared;
    my $excl = App::Lockd::Server::Claim->exclusive;
    ok($shared->is_same_as($shared), 'is same as');
    ok(! $shared->is_same_as($excl), 'different locks are not the same');
    ok(! $excl->is_same_as($shared), 'different locks are not the same both ways');
}

sub compatible {
    my $shared = App::Lockd::Server::Claim->shared;
    my $excl = App::Lockd::Server::Claim->exclusive;
    my $shared2 = App::Lockd::Server::Claim->shared;
    ok($shared->is_compatible_with($shared2), 'Shared locks are compatible with each other');
    ok(! $shared->is_compatible_with($excl), 'Shared lock is not compatible with exclusive lock');
    ok(! $excl->is_compatible_with($shared), 'Exclusive lock is not compatible with shared lock');
}

