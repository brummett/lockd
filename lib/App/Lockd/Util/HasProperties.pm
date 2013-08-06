package App::Lockd::Util::HasProperties;

use strict;
use warnings;

use Sub::Install;

sub import {
    my $caller = caller;

    foreach my $prop ( @_ ) {
        my $sub = sub {
            my $self = shift;
            if (@_) {
                $self->{$prop} = shift;
            }
            return $self->{$prop};
        };
    
        Sub::Install::install_sub({
            code => $sub,
            into => $caller,
            as   => $prop
         });
    }

    my $caller_new = "${caller}::new";
    unless (defined &$caller_new) {
        Sub::Install::install_sub({
            code => \&new,
            into => $caller,
            as => 'new',
        });
    }
}

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    while(@_) {
        my($key, $value) = splice(@_, 0, 2);
        $self->$key($value);
    }
    return $self;
}

1;
