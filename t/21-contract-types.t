use v5.32;
use strict;
use warnings;

use lib 't/lib';

use Test::More;

use Elegant::Perl ();
use Elegant::Perl::Contract ();
use Elegant::Test qw(
    define_class
    define_contract
    exception
);

sub validator_for {
    my ($type, $self_class) = @_;

    return Elegant::Perl::Contract::_compile_validator(
        $type,
        $self_class // 'T::Types::Self',
    );
}

{
    my $validator = validator_for('Scalar');

    ok($validator->{check}->('hello'), 'Scalar accepts string');
    ok($validator->{check}->(0), 'Scalar accepts zero');
    ok($validator->{check}->(12.5), 'Scalar accepts number');
    ok(!$validator->{check}->(undef), 'Scalar rejects undef');
    ok(!$validator->{check}->([]), 'Scalar rejects ARRAY ref');
    ok(!$validator->{check}->({}), 'Scalar rejects HASH ref');

    my $identity;
    my $object = bless \$identity, 'T::Types::Foreign';

    ok(!$validator->{check}->($object), 'Scalar rejects objects');
}

{
    my $validator = validator_for('Object');

    my $identity;
    my $object = bless \$identity, 'T::Types::Foreign';

    ok($validator->{check}->($object), 'Object accepts blessed object');
    ok(!$validator->{check}->('hello'), 'Object rejects scalar');
    ok(!$validator->{check}->([]), 'Object rejects unblessed ref');
    ok(!$validator->{check}->(undef), 'Object rejects undef');
}

{
    my $validator =
        validator_for(
            'Self',
            'T::Types::Exact',
        );

    my $left_id;
    my $right_id;

    my $left =
        bless \$left_id,
            'T::Types::Exact';

    my $right =
        bless \$right_id,
            'T::Types::Other';

    ok($validator->{check}->($left), 'Self accepts exact class');
    ok(!$validator->{check}->($right), 'Self rejects another class');
}

for my $type (qw(Int Num Str Bool)) {
    my $validator = validator_for($type);

    ok(
        !$validator->{check}->([]),
        "$type rejects an unblessed reference before Type::Tiny",
    );

    ok(
        !$validator->{check}->(undef),
        "$type rejects undef before Type::Tiny",
    );
}

my ($ok, $error) = define_contract(
    'T::Types::Money',
    q{
        sub amount
            :Builder
            :Returns(Num);
    },
);

ok($ok, 'Money contract compiles')
    or diag $error;

($ok, $error) = define_contract(
    'T::Types::Echoer',
    q{
        sub echo
            :Builder
            :Expects(T::Types::Money)
            :Returns(T::Types::Money);

        sub same
            :Builder
            :Expects(Self)
            :Returns(Self);

        sub object
            :Builder
            :Expects(Object)
            :Returns(Object);
    },
);

ok($ok, 'contract can use another contract as a type')
    or diag $error;

($ok, $error) = define_class(
    'T::Types::Currency',
    q{
        implements 'T::Types::Money';

        field 'amount';

        sub amount {
            my ($self) = @_;
            return value($self, 'amount');
        }
    },
);

ok($ok, 'first Money implementation compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Types::Coin',
    q{
        implements 'T::Types::Money';

        field 'amount';

        sub amount {
            my ($self) = @_;
            return value($self, 'amount');
        }
    },
);

ok($ok, 'second Money implementation compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Types::Echo',
    q{
        implements 'T::Types::Echoer';

        sub echo {
            my ($self, $money) = @_;
            return $money;
        }

        sub same {
            my ($self, $other) = @_;
            return $other;
        }

        sub object {
            my ($self, $object) = @_;
            return $object;
        }
    },
);

ok($ok, 'contract-typed implementation compiles')
    or diag $error;

my $currency =
    T::Types::Currency->new(
        amount => 10,
    );

my $coin =
    T::Types::Coin->new(
        amount => 3,
    );

my $echo =
    T::Types::Echo->new();

is(
    $echo->echo($currency),
    $currency,
    '<ContractName> accepts first implementation',
);

is(
    $echo->echo($coin),
    $coin,
    '<ContractName> accepts unrelated second implementation',
);

{
    my $identity;
    my $foreign =
        bless \$identity,
            'T::Types::Foreign';

    $error = exception(
        sub {
            $echo->echo($foreign);
        }
    );

    like(
        $error,
        qr/argument 1 does not satisfy T::Types::Money/,
        '<ContractName> rejects object that does not implement contract',
    );

    is(
        $echo->object($foreign),
        $foreign,
        'Object accepts arbitrary blessed object',
    );
}

is(
    $echo->same($echo),
    $echo,
    'Self accepts exact implementation class',
);

$error = exception(
    sub {
        $echo->same($currency);
    }
);

like(
    $error,
    qr/argument 1 does not satisfy Self/,
    'Self rejects another Elegant class',
);

$error = exception(
    sub {
        Elegant::Perl::Contract::_compile_validator(
            'Void',
            'T::Types::Echo',
        );
    }
);

like(
    $error,
    qr/Void is only valid as a return marker/,
    'Void cannot be compiled as a value validator',
);

$error = exception(
    sub {
        Elegant::Perl::Contract::_compile_validator(
            'T::Types::DoesNotExist',
            'T::Types::Echo',
        );
    }
);

like(
    $error,
    qr/(?:Can't locate .*DoesNotExist|Unknown Elegant::Perl type)/,
    'unknown type is rejected',
);

done_testing;
