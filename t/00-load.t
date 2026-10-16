use v5.32;
use warnings;

use Test::More;

BEGIN {
    require_ok('Elegant::Perl');
    require_ok('Elegant::Perl::Contract');
    require_ok('Elegant::Perl::Cap');
    require_ok('Elegant::Perl::Error');
}

is($Elegant::Perl::VERSION, '0.01', 'Elegant::Perl version');
is($Elegant::Perl::Contract::VERSION, '0.01', 'Contract version');

done_testing;
