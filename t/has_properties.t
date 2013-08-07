use strict;
use warnings;

use Test::More tests => 16;

package TestClass;

use App::Lockd::Util::HasProperties qw(prop_a prop_b);

package main;

my $t = TestClass->new();
ok($t, 'Create test object');

is($t->prop_a(), undef, 'Default property value is undef');
is($t->prop_a('value a'), 'value a', 'Setting property returns the set value');
is($t->prop_a, 'value a', 'Property retains its value');

is($t->prop_b, undef, 'Other property still has value undef');
is($t->prop_b('other value'), 'other value', 'Set second property value');
is($t->prop_b, 'other value', 'Second property retains its value');
is($t->prop_a, 'value a', 'First property retains its value');


my $t2 = TestClass->new(prop_a => 1, prop_b => 2);
is($t2->prop_a, 1, 'Constructor can take parameters');
is($t2->prop_b, 2, 'Constructor can take parameters');

my $t3 = eval { TestClass->new(crash_prop => 1) };
ok(! $t3, 'Call constructor with unknown property returns false');
like($@,
    qr(Can't locate object method "crash_prop" via package "TestClass"),
    'Exception complains about missing method "crash_prop"');



package TestClassNoNew;

use App::Lockd::Util::HasProperties qw(-nonew prop_a);

sub constructor {
    my $class = shift;
    return bless {}, $class;
}

package main;

my $t4 = eval { TestClassNoNew->new() };
ok(! $t4, 'Calling constructor on a -nonew class did not work');
like($@,
    qr(Can't locate object method "new" via package "TestClassNoNew"),
    'Exception matches expected');

$t4 = TestClassNoNew->constructor();
is($t4->prop_a(123), 123, 'Mutator still works');
is($t4->prop_a, 123, 'Accessor works');
