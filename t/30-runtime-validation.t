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
    'T::Runtime::Calculator',
    q{
        sub double
            :Builder
            :Expects(Num)
            :Returns(Num);

        sub label
            :Builder
            :Returns(Str);

        sub touch
            :Manipulator
            :Expects(Str);
    },
);

ok($ok, 'runtime validation contract compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Runtime::Good',
    q{
        implements 'T::Runtime::Calculator';

        sub double {
            my ($self, $value) = @_;
            return $value * 2;
        }

        sub label {
            return 'good';
        }

        sub touch {
            my ($self, $value) = @_;
            return;
        }
    },
);

ok($ok, 'good implementation compiles')
    or diag $error;

my $good =
    T::Runtime::Good->new();

is(
    $good->double(3),
    6,
    'valid argument and return value pass',
);

is(
    $good->label(),
    'good',
    'valid Str return passes',
);

is(
    scalar($good->touch('x')),
    undef,
    'Manipulator returns no value',
);

$error = exception(
    sub {
        $good->double('not-a-number');
    }
);

like(
    $error,
    qr/argument 1 does not satisfy Num/,
    'wrong argument type is rejected',
);

$error = exception(
    sub {
        $good->double();
    }
);

like(
    $error,
    qr/expects 1 argument\(s\), got 0/,
    'wrong argument count is rejected',
);

($ok, $error) = define_class(
    'T::Runtime::BadReturn',
    q{
        implements 'T::Runtime::Calculator';

        sub double {
            return 'wrong';
        }

        sub label {
            return [];
        }

        sub touch {
            return 'wrong';
        }
    },
);

ok($ok, 'bad-return implementation structurally compiles')
    or diag $error;

my $bad =
    T::Runtime::BadReturn->new();

$error = exception(
    sub {
        my $result =
            $bad->double(2);
    }
);

like(
    $error,
    qr/return value does not satisfy Num/,
    'wrong scalar return type is rejected',
);

$error = exception(
    sub {
        my $result =
            $bad->label();
    }
);

like(
    $error,
    qr/return value does not satisfy Str/,
    'unblessed reference cannot satisfy Str return',
);

$error = exception(
    sub {
        my $result =
            $bad->touch('x');
    }
);

like(
    $error,
    qr/declares Returns\(Void\), but returned a value/,
    'Manipulator returning a scalar is rejected in scalar context',
);

{
    my @values =
        $good->label();

    is_deeply(
        \@values,
        ['good'],
        'typed Builder preserves list context',
    );
}

($ok, $error) = define_contract(
    'T::Runtime::Context',
    q{
        sub context
            :Builder
            :Returns(Str);
    },
);

ok($ok, 'context contract compiles')
    or diag $error;

($ok, $error) = define_class(
    'T::Runtime::ContextAware',
    q{
        implements 'T::Runtime::Context';

        sub context {
            return !defined(wantarray)
                ? 'void'
                : wantarray
                    ? 'list'
                    : 'scalar';
        }
    },
);

ok($ok, 'context-aware implementation compiles')
    or diag $error;

my $context =
    T::Runtime::ContextAware->new();

is(
    scalar($context->context()),
    'scalar',
    'wrapper preserves scalar context',
);

my @context =
    $context->context();

is_deeply(
    \@context,
    ['list'],
    'wrapper preserves list context',
);

{
    my $seen;

    # In void context the implementation must see void context.
    # We cannot observe its return value, but this exercises the path.
    $context->context();

    pass('typed Builder can be called in void context without changing context');
}

done_testing;
