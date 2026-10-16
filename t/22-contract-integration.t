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
    'T::Integration::Renderable',
    q{
        sub render
            :Builder
            :Returns(Str);
    },
);

ok($ok, 'Renderable contract compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Integration::Good',
    q{
        implements 'T::Integration::Renderable';

        field 'text';

        sub render {
            my ($self) = @_;
            return value($self, 'text');
        }
    },
);

ok($ok, 'valid implementation compiles')
    or diag $error;

my $good =
    T::Integration::Good->new(
        text => 'hello',
    );

is(
    $good->render(),
    'hello',
    'valid contract implementation runs',
);

{
    my ($class_ok, $class_error) = define_class(
        'T::Integration::Missing',
        q{
            implements 'T::Integration::Renderable';
        },
    );

    ok($class_ok, 'missing implementation class definition itself compiles')
        or diag $class_error;

    $class_error = exception(
        sub {
            T::Integration::Missing->new();
        }
    );

    like(
        $class_error,
        qr/implements T::Integration::Renderable, but does not implement render\(\)/,
        'missing contract method is rejected at finalization',
    );
}

{
    my ($class_ok, $class_error) = define_class(
        'T::Integration::Extra',
        q{
            implements 'T::Integration::Renderable';

            sub render {
                return 'ok';
            }

            sub debug {
                return 'debug';
            }
        },
    );

    ok($class_ok, 'extra-method class definition compiles')
        or diag $class_error;

    $class_error = exception(
        sub {
            T::Integration::Extra->new();
        }
    );

    like(
        $class_error,
        qr/T::Integration::Extra::debug is public, but is not declared by any implemented contract/,
        'undeclared public method is rejected',
    );
}

{
    my ($class_ok, $class_error) = define_class(
        'T::Integration::ImportedSub',
        q{
            use Scalar::Util qw(blessed);
        },
    );

    ok($class_ok, 'class with imported function compiles')
        or diag $class_error;

    my $object;

    $class_error = exception(
        sub {
            $object =
                T::Integration::ImportedSub->new();
        }
    );

    is(
        $class_error,
        '',
        'imported functions are not treated as public methods',
    );
}

{
    my ($base_ok, $base_error) = define_class(
        'T::Integration::Inherited',
        q{
            our @ISA = ('T::Integration::SomeBase');
        },
    );

    ok($base_ok, 'inheriting class definition compiles')
        or diag $base_error;

    $base_error = exception(
        sub {
            T::Integration::Inherited->new();
        }
    );

    like(
        $base_error,
        qr/uses implementation inheritance; Elegant::Perl forbids inheritance/,
        'implementation inheritance is rejected',
    );
}

my ($same_a_ok, $same_a_error) = define_contract(
    'T::Integration::SameA',
    q{
        sub name
            :Builder
            :Returns(Str);
    },
);

ok($same_a_ok, 'first identical contract compiles')
    or diag $same_a_error;

my ($same_b_ok, $same_b_error) = define_contract(
    'T::Integration::SameB',
    q{
        sub name
            :Builder
            :Returns(Str);
    },
);

ok($same_b_ok, 'second identical contract compiles')
    or diag $same_b_error;

{
    my ($class_ok, $class_error) = define_class(
        'T::Integration::SameImplementation',
        q{
            implements(
                'T::Integration::SameA',
                'T::Integration::SameB',
            );

            sub name {
                return 'same';
            }
        },
    );

    ok($class_ok, 'class can implement identical method contracts')
        or diag $class_error;

    my $object =
        T::Integration::SameImplementation->new();

    is(
        $object->name(),
        'same',
        'identical contract signatures do not conflict',
    );
}

my ($different_ok, $different_error) = define_contract(
    'T::Integration::Different',
    q{
        sub name
            :Builder
            :Returns(Num);
    },
);

ok($different_ok, 'conflicting contract compiles')
    or diag $different_error;

{
    my ($class_ok, $class_error) = define_class(
        'T::Integration::Conflict',
        q{
            implements(
                'T::Integration::SameA',
                'T::Integration::Different',
            );

            sub name {
                return 'name';
            }
        },
    );

    ok($class_ok, 'conflicting implementation definition compiles')
        or diag $class_error;

    $class_error = exception(
        sub {
            T::Integration::Conflict->new();
        }
    );

    like(
        $class_error,
        qr/Contract conflict for T::Integration::Conflict::name/,
        'conflicting contract signatures are rejected',
    );
}

done_testing;
