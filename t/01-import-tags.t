use v5.32;
use strict;
use warnings;
use utf8;

use lib 't/lib';

use Test::More;

use Elegant::Perl ();
use Elegant::Test qw(exception);

is_deeply(
    [Elegant::Perl->_expand_tags(':core')],
    [
        'utf8',
        'strict',
        'warnings',
    ],
    ':core expands correctly',
);

is_deeply(
    [Elegant::Perl->_expand_tags(':modern')],
    [
        'utf8',
        'strict',
        'warnings',
        ['feature', ':5.32'],
    ],
    ':modern expands nested tags',
);

is_deeply(
    [Elegant::Perl->_expand_tags(':compat')],
    [
        'Feature::Compat::Try',
        'Feature::Compat::Defer',
    ],
    ':compat expands nested tags',
);

is_deeply(
    [Elegant::Perl->_expand_tags(':all')],
    [
        'utf8',
        'strict',
        'warnings',
        ['feature', ':5.32'],
        ['feature', 'signatures'],
        ['experimental', 'signatures'],
        ['feature', 'isa'],
        ['experimental', 'isa'],
        'Feature::Compat::Try',
        'Feature::Compat::Defer',
    ],
    ':all expands to the complete feature set',
);

my $error = exception(
    sub {
        Elegant::Perl->_expand_tags(':does_not_exist');
    }
);

like(
    $error,
    qr/Unknown Elegant::Perl tag :does_not_exist/,
    'unknown tag reports Elegant::Perl namespace',
);

{
    my $ok = eval q{
        package T::Import::CoreStrict;
        use Elegant::Perl ':core';

        $not_declared = 1;

        1;
    };

    ok(!$ok, ':core imports strict');
    like($@, qr/Global symbol "\$not_declared"/, 'strict error is visible');
}

{
    my @warnings;

    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    my $ok = eval q{
        package T::Import::CoreWarnings;
        use Elegant::Perl ':core';

        my $undefined;
        my $number = $undefined + 1;

        1;
    };

    ok($ok, ':core package compiles');
    ok(
        scalar(grep { /uninitialized/i } @warnings),
        ':core imports warnings',
    );
}

{
    my $ok = eval q{
        package T::Import::Features532;
        use Elegant::Perl ':features_532';

        sub bump {
            state $value = 0;
            return ++$value;
        }

        1;
    };

    ok($ok, ':features_532 enables the 5.32 feature bundle')
        or diag $@;
}

{
    my $ok = eval q{
        package T::Import::Signatures;
        use Elegant::Perl ':signatures';

        sub add ($left, $right) {
            return $left + $right;
        }

        1;
    };

    ok($ok, ':signatures enables signatures')
        or diag $@;

    is(
        T::Import::Signatures::add(2, 3),
        5,
        'signature-enabled sub executes',
    ) if $ok;
}

{
    my $ok = eval q{
        package T::Import::Isa;
        use Elegant::Perl ':isa';

        sub is_object {
            my ($value) = @_;
            return $value isa T::Import::Isa::Object;
        }

        package T::Import::Isa::Object;

        1;
    };

    ok($ok, ':isa enables isa operator')
        or diag $@;

    if ($ok) {
        my $object = bless {}, 'T::Import::Isa::Object';

        ok(
            T::Import::Isa::is_object($object),
            'isa operator works',
        );
    }
}

{
    my $ok = eval q{
        package T::Import::Try;
        use Elegant::Perl ':try';

        our $RESULT = '';

        try {
            die "boom\n";
        }
        catch ($error) {
            $RESULT = 'caught';
        }

        1;
    };

    ok($ok, ':try imports Feature::Compat::Try')
        or diag $@;

    is(
        $T::Import::Try::RESULT,
        'caught',
        'try/catch executes',
    ) if $ok;
}

{
    my $ok = eval q{
        package T::Import::Defer;
        use Elegant::Perl ':defer';

        our $TRACE = '';

        {
            defer {
                $TRACE .= 'B';
            }

            $TRACE .= 'A';
        }

        1;
    };

    ok($ok, ':defer imports Feature::Compat::Defer')
        or diag $@;

    is(
        $T::Import::Defer::TRACE,
        'AB',
        'defer executes at scope exit',
    ) if $ok;
}

{
    my $ok = eval q{
        package T::Import::DefaultAll;
        use Elegant::Perl;

        sub identity ($value) {
            return $value;
        }

        1;
    };

    ok($ok, 'no import tags defaults to :all')
        or diag $@;
}

done_testing;
