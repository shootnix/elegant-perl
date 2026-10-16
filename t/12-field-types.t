use v5.32;
use strict;
use warnings;

use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use Elegant::Perl ();
use Elegant::Test qw(define_class define_contract exception);

my ($ok, $error) = define_class('T::FieldTypes::Values', q{
    field 'count' => 'Int';
    field 'amount' => 'Num';
    field 'enabled' => 'Bool';
    field 'label' => 'Str';
    field 'legacy';
    cap 'Public' => {
        count => sub { value($_[0], 'count') },
        legacy => sub { value($_[0], 'legacy') },
    };
});
ok($ok, 'typed and untyped fields can be mixed') or diag $error;
my %valid = (count => 0, amount => 12.5, enabled => 0, label => 'hello', legacy => 'anything');
my $object = T::FieldTypes::Values->new(%valid);
is($object->as_cap('Public')->count, 0, 'valid typed fields are stored and zero is accepted');

for my $case (
    ['count', 1.5, 'Int'], ['amount', 'bad', 'Num'],
    ['enabled', 2, 'Bool'], ['label', $object, 'Str'],
) {
    my ($field, $value, $type) = @$case;
    like(exception(sub { T::FieldTypes::Values->new(%valid, $field => $value) }),
        qr/specified more than once/, 'duplicate detection also applies to typed fields');
    my %args = (%valid, $field => $value);
    like(exception(sub { T::FieldTypes::Values->new(%args) }),
        qr/field '$field' does not satisfy $type/, "$type rejects invalid field value");
}
for my $value (undef, [], {}) {
    my %args = (%valid, count => $value);
    like(exception(sub { T::FieldTypes::Values->new(%args) }),
        qr/must contain a defined scalar or a blessed object/,
        'typed fields retain the defined-value and no-unblessed-reference rules');
}
my %missing = %valid;
delete $missing{count};
like(exception(sub { T::FieldTypes::Values->new(%missing) }), qr/missing required field 'count'/,
    'typed fields remain mandatory');
my %with_object = (%valid, legacy => $object);
is(T::FieldTypes::Values->new(%with_object)->as_cap('Public')->legacy, $object,
    'untyped fields still accept arbitrary objects');

($ok, $error) = define_contract('T::FieldTypes::Named', q{
    sub name :Builder :Returns(Str);
});
ok($ok, 'field contract compiles') or diag $error;
($ok, $error) = define_class('T::FieldTypes::Customer', q{
    implements 'T::FieldTypes::Named';
    field 'name' => 'Str';
    cap 'Billing' => { name => sub { value($_[0], 'name') } };
    cap 'Public' => { name => sub { value($_[0], 'name') } };
    sub name { value($_[0], 'name') }
});
ok($ok, 'source with typed fields and caps compiles') or diag $error;
my $customer = T::FieldTypes::Customer->new(name => 'Alice');
($ok, $error) = define_class('T::FieldTypes::Billing', q{
    field 'customer' => 'T::FieldTypes::Customer::Cap::Billing';
    field 'named' => 'T::FieldTypes::Named';
    field 'anything' => 'Object';
    field 'scalar' => 'Scalar';
    cap 'Public' => {
        customer => sub { value($_[0], 'customer') },
        named => sub { value($_[0], 'named') },
    };
});
ok($ok, 'constructor can require caps and contracts') or diag $error;
my $cap = $customer->as_cap('Billing');
my %args = (customer => $cap, named => $customer, anything => $object, scalar => 'data');
my $billing = T::FieldTypes::Billing->new(%args);
is($billing->as_cap('Public')->customer, $cap, 'constructor retains the exact supplied cap');
is($billing->as_cap('Public')->named, $customer, 'constructor accepts contract implementation');
my $identity;
my $forged = bless \$identity, 'T::FieldTypes::Customer::Cap::Billing';
for my $value ($customer, $customer->as_cap('Public'), $forged, 'Alice') {
    my %bad = (%args, customer => $value);
    like(exception(sub { T::FieldTypes::Billing->new(%bad) }),
        qr/field 'customer' does not satisfy T::FieldTypes::Customer::Cap::Billing/,
        'cap field rejects full object, wrong cap, forgery, and scalar');
}
for my $case (['named', $object, 'T::FieldTypes::Named'], ['anything', 'text', 'Object'],
    ['scalar', $object, 'Scalar']) {
    my ($name, $value, $type) = @$case;
    my %bad = (%args, $name => $value);
    like(exception(sub { T::FieldTypes::Billing->new(%bad) }),
        qr/field '$name' does not satisfy \Q$type\E/, "$type field checks its declared type");
}

my $index = 0;
for my $case (
    [q{field 'value', 'Int', 'Str'}, qr/expects a name and an optional type/],
    [q{field 'value', undef}, qr/type must be a type name/],
    [q{field 'value', []}, qr/type must be a type name/],
    [q{field 'value', 'bad-type'}, qr/type must be a type name/],
    [q{field 'value', 'Void'}, qr/cannot use Void/],
) {
    ($ok, $error) = define_class('T::FieldTypes::Invalid' . ++$index, $case->[0] . ';');
    ok(!$ok, 'invalid typed field declaration is rejected');
    like($error, $case->[1], 'declaration error identifies the problem');
}
($ok, $error) = define_class('T::FieldTypes::Unknown', q{field 'value' => 'MissingFieldType';});
ok($ok, 'type resolution is deferred until finalization') or diag $error;
like(exception(sub { T::FieldTypes::Unknown->new(value => 1) }),
    qr/Can't locate MissingFieldType.pm/, 'unknown type fails during finalization');
($ok, $error) = define_class('T::FieldTypes::Concrete', q{
    field 'value' => 'T::FieldTypes::Customer';
});
ok($ok, 'concrete type declaration parses before resolution') or diag $error;
like(exception(sub { T::FieldTypes::Concrete->new(value => $customer) }),
    qr/Unknown Elegant::Perl type/, 'ordinary class names remain unsupported as named contract types');

# Verify CHECK resolves field types without constructing instances, and that
# a cap field loads the owning module rather than requiring a generated file.
{
    my $dir = tempdir(CLEANUP => 1);
    open my $file, '>', "$dir/FieldCapOwner.pm" or die $!;
    print {$file} <<'PERL';
package FieldCapOwner;
use Elegant::Perl ':core';
cap 'Public' => { label => sub { 'label' } };
1;
PERL
    close $file or die $!;
    for my $case (
        ['Good', 'FieldCapOwner::Cap::Public', 0, qr/checked/],
        ['Bad', 'MissingFieldType', 1, qr/Can't locate MissingFieldType.pm/],
    ) {
        my ($name, $type, $status, $message) = @$case;
        open $file, '>', "$dir/FieldCheck$name.pm" or die $!;
        print {$file} "package FieldCheck$name; use Elegant::Perl ':core'; "
            . "field 'value' => '$type'; 1;";
        close $file or die $!;
        my $script = "BEGIN { open STDERR, '>&', STDOUT or die \$! } "
            . "use FieldCheck$name; print 'checked';";
        open my $process, '-|', $^X, '-Ilib', "-I$dir", '-e', $script or die $!;
        my $output = do { local $/; <$process> };
        close $process;
        is($? != 0 ? 1 : 0, $status, "$name field type has expected CHECK status");
        like($output, $message, "$name field type is resolved without constructing an instance");
    }
}

done_testing;
