use strict;
use warnings;

use Test::More tests => 40;

use App::Lockd::Server::Resource;
use App::Lockd::Server::Claim;
use App::Lockd::Server::Command::UpgradeLock;
use App::Lockd::Server::Command::Lock;
use App::Lockd::Server::Command::Release;
use App::Lockd::LockType qw(LOCK_EXCLUSIVE LOCK_SHARED);

failed_upgrade();
immediate_upgrade_no_waiters();
immediate_upgrade_with_waiters();
delayed_upgrade();
upgrade_waiting_claim();

sub failed_upgrade {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $c = App::Lockd::Server::Claim->exclusive(resource => $r);
    my $success = App::Lockd::Server::Command::Lock->execute(
            claim => $c,
            success => sub { } );
    ok($success, 'exclusive lock');

    my $called = 0;
    $success = App::Lockd::Server::Command::UpgradeLock->execute(
                    claim => $c,
                    success => sub { $called++ });
    ok(! $success, 'Cannot upgrade an exclusive lock');
    is($called, 0, 'Callback was not called');
    is($r->state, LOCK_EXCLUSIVE, 'resource is still exclusive locked');
    ok($r->is_holding($c), 'Claim is still holding the lock');
}


sub immediate_upgrade_no_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $c = App::Lockd::Server::Claim->shared(resource => $r);

    my $success = App::Lockd::Server::Command::Lock->execute(
            claim => $c,
            success => sub { } );
    ok($success, 'shared lock');
    is($r->state, LOCK_SHARED, 'resource is shared locked');

    my $upgraded = 0;
    $success = App::Lockd::Server::Command::UpgradeLock->execute(
                    claim => $c,
                    success => sub { $upgraded++ });
    ok($success, 'Upgraded lock');
    is($upgraded, 1, 'Callback was called');
    is($r->state, LOCK_EXCLUSIVE, 'Resource is now exclusive locked');
    is($c->type, LOCK_EXCLUSIVE, 'Claim is now type exclusive');
    ok($r->is_holding($c), 'Claim is still holding the lock');
}

sub immediate_upgrade_with_waiters {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $shared = App::Lockd::Server::Claim->shared(resource => $r);
    my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);

    my $success = App::Lockd::Server::Command::Lock->execute(
            claim => $shared,
            success => sub { } );
    ok($success, 'shared lock');

    $success = App::Lockd::Server::Command::Lock->execute(
            claim => $excl,
            success => sub { } );
    ok($success, 'add waiting exclusive lock');

    is($r->state, LOCK_SHARED, 'resource is shared locked');

    my $upgraded = 0;
    $success = App::Lockd::Server::Command::UpgradeLock->execute(
                    claim => $shared,
                    success => sub { $upgraded++ });
    ok($success, 'upgrade lock');
    is($upgraded, 1, 'Callback was called');
    is($r->state, LOCK_EXCLUSIVE, 'Resource is now exclusive locked');
    is($shared->type, LOCK_EXCLUSIVE, 'original shared claim is now exclusive');
    ok($r->is_holding($shared), 'Original claim is still holding the lock');
    ok(! $r->is_holding($excl), 'Original exclusive claim is not holding the lock');
    ok($r->is_waiting($excl), 'Original exclusive claim is still waiting for the lock');
}

sub delayed_upgrade {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $shared_1 = App::Lockd::Server::Claim->shared(resource => $r);
    my $shared_2 = App::Lockd::Server::Claim->shared(resource => $r);

    foreach my $c ( $shared_1, $shared_2 ) {
        App::Lockd::Server::Command::Lock->execute(
            claim => $c,
            success => sub {} );
    }

    is($r->state, LOCK_SHARED, 'resource starts off shared locked');

    my $upgraded = 0;
    my $success = App::Lockd::Server::Command::UpgradeLock->execute(
                    claim => $shared_1,
                    success => sub { $upgraded++ });
    ok(! $success, 'Upgrade was delayed while another shared claim is active');
    is($upgraded, 0, 'Callback was not called');
    is($r->state, LOCK_SHARED, 'Resource is still shared locked');

    ok($r->is_holding($shared_2), 'Shared claim 2 is holding the resource');
    ok($r->is_waiting($shared_1), 'Original shared claim is waiting');
    is($shared_1->type, LOCK_EXCLUSIVE, 'Original shared claim is now exclusive');

    $success = App::Lockd::Server::Command::Release->execute( claim => $shared_2 );
    ok($success, 'Release the second shared lock');
    is($upgraded, 1, 'Upgrade callback was called');
    ok($r->is_holding($shared_1), 'Upgraded lock is now holding the resource');
    is($r->state, LOCK_EXCLUSIVE, 'Resource is now exclusive locked');
}


sub upgrade_waiting_claim {
    my $r = App::Lockd::Server::Resource->get(__LINE__);
    my $shared = App::Lockd::Server::Claim->shared(resource => $r);
    my $excl = App::Lockd::Server::Claim->exclusive(resource => $r);

    my $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $excl,
                    success => sub {} );
    ok($success, 'exclusive lock');

    $success = App::Lockd::Server::Command::Lock->execute(
                    claim => $shared,
                    success => sub {} );
    ok($success, 'queue up shared lock');

    my $upgraded = 0;
    $success = App::Lockd::Server::Command::UpgradeLock->execute(
                    claim => $shared,
                    success => sub { $upgraded++ });
    ok($success, 'Upgrade waiting shared claim');
    is($upgraded, 1, 'Upgrade callback was called');

    ok($r->is_holding($excl), 'original exclusive lock is holding the resource');
    ok($r->is_waiting($shared), 'upgraded lock is still waiting');
    is($shared->type, LOCK_EXCLUSIVE, 'upgraded lock is now exclusive');
}
