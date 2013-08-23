package App::Lockd::Util;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw(required_params);

sub required_params {
    my($required_list, %params) = @_;

    my @retval;
    foreach my $param_name ( @$required_list ) {
        Carp::croak("Parameter $param_name is required")
            unless exists $params{$param_name};
        push @retval, $params{$param_name};
    }
    return @retval;
}


1;
