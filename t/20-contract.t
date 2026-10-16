use v5.32;
use strict;
use warnings;

use lib 't/lib';

use Test::More;

use Elegant::Perl::Contract ();
use Elegant::Test qw(
    define_contract
    exception
);

my ($ok, $error) = define_contract(
    'T::Contract::Storage',
    q{
        sub content
            :Builder
            :Returns(Str);

        sub write
            :Manipulator
            :Expects(Str);

        sub close
            :Manipulator;
    },
);

ok($ok, 'valid contract compiles')
    or diag $error;

ok(
    Elegant::Perl::Contract::_is_contract(
        'T::Contract::Storage'
    ),
    'contract is registered',
);

my $definition =
    Elegant::Perl::Contract::_definition(
        'T::Contract::Storage'
    );

is(
    $definition->{name},
    'T::Contract::Storage',
    'definition contains contract name',
);

is(
    $definition->{methods}{content}{kind},
    'Builder',
    'Builder kind is retained',
);

is(
    $definition->{methods}{content}{returns},
    'Str',
    'Builder return type is retained',
);

is(
    $definition->{methods}{write}{kind},
    'Manipulator',
    'Manipulator kind is retained',
);

is_deeply(
    $definition->{methods}{write}{expects},
    ['Str'],
    'Expects list is retained',
);

is(
    $definition->{methods}{write}{returns},
    'Void',
    'Manipulator implicitly returns Void',
);

is(
    $definition->{methods}{close}{returns},
    'Void',
    'argument-less Manipulator also implicitly returns Void',
);

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::ExplicitVoid',
        q{
            sub close
                :Manipulator
                :Returns(Void);
        },
    );

    ok($contract_ok, 'explicit Returns(Void) on Manipulator is allowed')
        or diag $contract_error;

    my $def =
        Elegant::Perl::Contract::_definition(
            'T::Contract::ExplicitVoid'
        );

    is(
        $def->{methods}{close}{returns},
        'Void',
        'explicit Void is preserved',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::NoKind',
        q{
            sub foo
                :Returns(Str);
        },
    );

    ok($contract_ok, 'contract declaration compiles before semantic validation')
        or diag $contract_error;

    $contract_error = exception(
        sub {
            Elegant::Perl::Contract::_definition(
                'T::Contract::NoKind'
            );
        }
    );

    like(
        $contract_error,
        qr/must declare exactly one of :Builder or :Manipulator/,
        'every method must declare a semantic kind',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::BuilderNoReturn',
        q{
            sub foo
                :Builder;
        },
    );

    ok($contract_ok, 'Builder without return compiles before definition check')
        or diag $contract_error;

    $contract_error = exception(
        sub {
            Elegant::Perl::Contract::_definition(
                'T::Contract::BuilderNoReturn'
            );
        }
    );

    like(
        $contract_error,
        qr/is a :Builder and must declare :Returns/,
        'Builder must declare a return type',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::BuilderVoid',
        q{
            sub foo
                :Builder
                :Returns(Void);
        },
    );

    ok($contract_ok, 'Builder/Void syntax compiles before definition check')
        or diag $contract_error;

    $contract_error = exception(
        sub {
            Elegant::Perl::Contract::_definition(
                'T::Contract::BuilderVoid'
            );
        }
    );

    like(
        $contract_error,
        qr/is a :Builder and cannot :Returns\(Void\)/,
        'Builder cannot return Void',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::ManipulatorValue',
        q{
            sub foo
                :Manipulator
                :Returns(Str);
        },
    );

    ok($contract_ok, 'Manipulator/value syntax compiles before definition check')
        or diag $contract_error;

    $contract_error = exception(
        sub {
            Elegant::Perl::Contract::_definition(
                'T::Contract::ManipulatorValue'
            );
        }
    );

    like(
        $contract_error,
        qr/is a :Manipulator and cannot return 'Str'/,
        'Manipulator cannot return a value',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::Implementation',
        q{
            sub foo :Builder :Returns(Str) {
                return 'bad';
            }
        },
    );

    ok($contract_ok, 'implemented contract method compiles')
        or diag $contract_error;

    $contract_error = exception(
        sub {
            Elegant::Perl::Contract::_definition(
                'T::Contract::Implementation'
            );
        }
    );

    like(
        $contract_error,
        qr/contains implementation; contract methods must be declarations only/,
        'contract implementation is rejected',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::DoubleKind',
        q{
            sub foo
                :Builder
                :Manipulator
                :Returns(Str);
        },
    );

    ok(!$contract_ok, 'Builder and Manipulator cannot be combined');

    like(
        $contract_error,
        qr/already declares :Builder/,
        'double semantic kind reports conflict',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::VoidArgument',
        q{
            sub foo
                :Manipulator
                :Expects(Void);
        },
    );

    ok(!$contract_ok, 'Void cannot be used as an argument type');

    like(
        $contract_error,
        qr/cannot use Void in :Expects/,
        'Void argument has a useful error',
    );
}

{
    my ($contract_ok, $contract_error) = define_contract(
        'T::Contract::MultipleReturns',
        q{
            sub foo
                :Builder
                :Returns(Str, Int);
        },
    );

    ok(!$contract_ok, 'multiple return types are rejected');

    like(
        $contract_error,
        qr/:Returns must contain exactly one type/,
        'multiple return types have a useful error',
    );
}

done_testing;
