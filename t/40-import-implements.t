use v5.32;
use strict;
use warnings;

use lib 't/lib';

use Test::More;

use Elegant::Perl ();
use Elegant::Test qw(
    define_class
    define_contract
    exception
);

my ($ok, $error) = define_contract(
    'T::Implements::One',
    q{
        sub one
            :Builder
            :Returns(Str);
    },
);

ok($ok, 'first contract compiles')
    or diag $error;

($ok, $error) = define_contract(
    'T::Implements::Two',
    q{
        sub two
            :Builder
            :Returns(Str);
    },
);

ok($ok, 'second contract compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Implements::Both',
    q{
        implements(
            'T::Implements::One',
            'T::Implements::Two',
        );

        sub one {
            return 'one';
        }

        sub two {
            return 'two';
        }
    },
);

ok($ok, 'multiple contracts can be declared at once')
    or diag $error;

my $both =
    T::Implements::Both->new();

is($both->one(), 'one', 'first contract method works');
is($both->two(), 'two', 'second contract method works');

{
    my ($class_ok, $class_error) = define_class(
        'T::Implements::Duplicate',
        q{
            implements 'T::Implements::One';
            implements 'T::Implements::One';

            sub one {
                return 'one';
            }
        },
    );

    ok(!$class_ok, 'same contract cannot be declared twice');

    like(
        $class_error,
        qr/already implements T::Implements::One/,
        'duplicate implements has useful error',
    );
}

{
    my ($class_ok, $class_error) = define_class(
        'T::Implements::Unknown',
        q{
            implements 'T::Implements::DoesNotExist';
        },
    );

    ok(!$class_ok, 'missing contract module is rejected');

    like(
        $class_error,
        qr/Can't locate T\/Implements\/DoesNotExist\.pm/,
        'missing contract reports require failure',
    );
}

{
    package T::Implements::NotAContract;
}

BEGIN {
    $INC{'T/Implements/NotAContract.pm'} = __FILE__;
}

{
    my ($class_ok, $class_error) = define_class(
        'T::Implements::WrongModule',
        q{
            implements 'T::Implements::NotAContract';
        },
    );

    ok(!$class_ok, 'ordinary package cannot be used as a contract');

    like(
        $class_error,
        qr/is not declared with Elegant::Perl::Contract/,
        'ordinary package has useful contract error',
    );
}

done_testing;
