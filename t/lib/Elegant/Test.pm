package Elegant::Test;

use v5.32;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
    define_class
    define_contract
    exception
    mark_loaded
);

sub mark_loaded {
    my ($package) = @_;

    (my $file = "$package.pm") =~ s{::}{/}g;
    $INC{$file} //= __FILE__;

    return;
}

sub define_contract {
    my ($package, $body) = @_;

    mark_loaded($package);

    my $source = <<"PERL";
package $package;
use Elegant::Perl::Contract;
$body
1;
PERL

    my $ok = eval $source;
    my $error = $@;

    return wantarray
        ? ($ok, $error)
        : $ok;
}

sub define_class {
    my ($package, $body, $tag) = @_;

    $tag //= ':core';

    mark_loaded($package);

    my $source = <<"PERL";
package $package;
use Elegant::Perl '$tag';
$body
1;
PERL

    my $ok = eval $source;
    my $error = $@;

    return wantarray
        ? ($ok, $error)
        : $ok;
}

sub exception {
    my ($code) = @_;

    local $@;

    my $ok = eval {
        $code->();
        1;
    };

    return '' if $ok;
    return $@;
}

1;
