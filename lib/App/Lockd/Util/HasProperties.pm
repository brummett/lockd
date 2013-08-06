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
}

1;
