use strict;
use warnings;

use Test::More tests => 8;

package TestClass;

use App::Lockd::Util::HasProperties qw(prop_a prop_b);

sub new {
    return bless {}, shift;
}

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

