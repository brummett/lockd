use App::Lockd::Client;

my $resource = shift @ARGV;

my $lock_server = App::Lockd::Client->new(host => 'localhost', port => 22334);
$lock_server || die "can't connect to server";

$|=1;
print "Locking... ";
my $lock = $lock_server->lock_exclusive($resource);
if ($lock) {
    print "locked\n";
    select(undef, undef, undef, undef);
} else {
    die "Lock failed";
}
