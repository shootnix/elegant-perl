use v5.32;
use strict;
use warnings;

use lib 't/lib';
use Test::More;
use Scalar::Util qw(weaken);
use File::Temp qw(tempdir);
use Elegant::Perl ();
use Elegant::Test qw(define_class define_contract exception);

my ($ok, $error) = define_contract('T::Cap::CustomerContract', q{
    sub secret :Builder :Returns(Str);
});
ok($ok, 'owner contract compiles') or diag $error;

($ok, $error) = define_class('T::Cap::Customer', q{
    implements 'T::Cap::CustomerContract';
    cap 'Billing' => {
        name => sub { value($_[0], 'name') },
        email => sub { value($_[0], 'billing_address') },
        label => sub { my ($self, $prefix) = @_; $prefix . value($self, 'name') },
        context => sub { !defined(wantarray) ? 'void' : wantarray ? ('list', 'result') : 'scalar' },
        fail => sub { die "callback failed\n" },
    };
    cap 'Public' => { name => sub { value($_[0], 'name') } };
    field 'name';
    field 'billing_address';
    field 'password_hash';
    sub secret { return value($_[0], 'password_hash') }
});
ok($ok, 'caps can be declared before their fields') or diag $error;

my $customer = T::Cap::Customer->new(
    name => 'Alice', billing_address => 'alice@example.test', password_hash => 'secret',
);
my $billing = $customer->as_cap('Billing');
my $public = $customer->as_cap('Public');
is(ref($billing), 'T::Cap::Customer::Cap::Billing', 'cap has its own named type');
is($billing->name, 'Alice', 'first selected field is readable');
is($billing->email, 'alice@example.test', 'public method is independent of internal field name');
is($public->name, 'Alice', 'another subset reads the same source');

for my $method (qw(password_hash billing_address secret as_cap value new)) {
    like(exception(sub { $billing->$method() }), qr/Can't locate object method/,
        "cap does not expose $method");
}
like(exception(sub { $public->email }), qr/Can't locate object method/,
    'smaller cap cannot read a larger cap field');
like(exception(sub { $billing->{email} }), qr/Not a HASH reference|Can't use .* as a HASH ref/,
    'cap state is not available through hash dereference');
is($billing->label('Customer: '), 'Customer: Alice', 'callback receives source and method arguments');
is(scalar($billing->context), 'scalar', 'callback sees scalar context');
my @context = $billing->context;
is_deeply(\@context, ['list', 'result'], 'callback sees list context and may return multiple values');
like(exception(sub { $billing->fail }), qr/callback failed/, 'callback exceptions propagate');
like(exception(sub { T::Cap::Customer::Cap::Billing->email }), qr/Invalid .* cap/,
    'reader rejects class invocation');
my $email = $billing->email;
$email = 'replacement';
is($billing->email, 'alice@example.test', 'changing a returned scalar does not change source');
like(exception(sub { $customer->as_cap('Missing') }), qr/has no cap 'Missing'/,
    'unknown cap is rejected');
like(exception(sub { T::Cap::Customer->as_cap('Billing') }), qr/expects an instance/,
    'class invocation cannot issue a cap');
like(exception(sub { $customer->as_cap([]) }), qr/Cap name must be an identifier/,
    'invalid cap name is rejected');
like(exception(sub { $customer->as_cap() }), qr/expects object and cap name/,
    'issuer enforces arity');

my $identity;
my $forged = bless \$identity, 'T::Cap::Customer::Cap::Billing';
like(exception(sub { $forged->email }), qr/Invalid .* cap/,
    'blessing an identity does not forge a readable cap');
my $source_id;
my $fake_source = bless \$source_id, 'T::Cap::Customer';
like(exception(sub { $fake_source->as_cap('Billing') }), qr/expects an instance/,
    'forged source cannot issue a cap');

($ok, $error) = define_contract('T::Cap::EchoContract', q{
    sub echo :Builder :Expects(T::Cap::Customer::Cap::Billing)
        :Returns(T::Cap::Customer::Cap::Billing);
    sub leak :Builder :Returns(T::Cap::Customer::Cap::Billing);
});
ok($ok, 'cap types are accepted in contract declarations') or diag $error;
($ok, $error) = define_class('T::Cap::Echo', q{
    implements 'T::Cap::EchoContract';
    field 'source';
    sub echo { return $_[1] }
    sub leak { return value($_[0], 'source') }
});
ok($ok, 'cap-typed consumer compiles') or diag $error;
my $echo = T::Cap::Echo->new(source => $customer);
is($echo->echo($billing), $billing, 'cap passes argument and scalar return checks');
my @result = $echo->echo($billing);
is_deeply(\@result, [$billing], 'cap return checks preserve list context');
for my $case (
    ['full source object', $customer], ['another cap', $public],
    ['forged cap', $forged], ['scalar', 'Alice'],
) {
    like(exception(sub { $echo->echo($case->[1]) }), qr/argument 1 does not satisfy/,
        "cap argument rejects $case->[0]");
}
like(exception(sub { my $result = $echo->leak }), qr/return value does not satisfy/,
    'full source object cannot satisfy a cap return contract');
like(exception(sub { my @result = $echo->leak }), qr/return value does not satisfy/,
    'cap return contract is enforced in list context');

($ok, $error) = define_class('T::Cap::OtherCustomer', q{
    field 'name'; field 'email';
    cap 'Billing' => {
        name => sub { value($_[0], 'name') },
        email => sub { value($_[0], 'email') },
    };
});
ok($ok, 'another owner can declare the same cap shape') or diag $error;
my $other = T::Cap::OtherCustomer->new(name => 'Bob', email => 'bob@example.test');
like(exception(sub { $echo->echo($other->as_cap('Billing')) }), qr/argument 1 does not satisfy/,
    'equal field sets from different owners are distinct types');

{
    my $source = T::Cap::Customer->new(
        name => 'Retained', billing_address => 'retained@example.test', password_hash => 'hidden',
    );
    my $weak_source = $source;
    weaken($weak_source);
    my $cap = $source->as_cap('Billing');
    my $weak_cap = $cap;
    weaken($weak_cap);
    undef $source;
    ok(defined $weak_source, 'cap keeps its source alive');
    is($cap->name, 'Retained', 'cap still reads after original reference is released');
    undef $cap;
    ok(!defined $weak_cap, 'cap is released without a retention cycle');
    ok(!defined $weak_source, 'source is released with the last cap');
}

# A cap does not copy object-valued fields or make them deeply immutable.
($ok, $error) = define_class('T::Cap::Holder', q{
    field 'child'; cap 'Nested' => { child => sub { value($_[0], 'child') } };
});
ok($ok, 'object-valued cap compiles') or diag $error;
my $holder = T::Cap::Holder->new(child => $public);
is($holder->as_cap('Nested')->child, $public, 'object-valued fields retain their identity');

($ok, $error) = define_class('T::Cap::Snapshot', q{
    use feature 'signatures';
    no warnings 'experimental::signatures';
    my $seen;
    my $methods = {
        name => sub ($self) { value($self, 'internal_name') },
        observe => sub ($self) {
            $seen = !defined(wantarray) ? 'void' : wantarray ? 'list' : 'scalar';
            return $seen;
        },
        observed => sub ($self) { $seen },
    };
    cap 'Public' => $methods;
    $methods->{name} = sub { 'replacement' };
    $methods->{injected} = sub { 'extra' };
    delete $methods->{observed};
    field 'internal_name';
});
ok($ok, 'cap accepts callbacks with Perl signatures') or diag $error;
my $snapshot = T::Cap::Snapshot->new(internal_name => 'Original')->as_cap('Public');
is($snapshot->name, 'Original', 'changing declaration hash cannot replace an implementation');
like(exception(sub { $snapshot->injected }), qr/Can't locate object method/,
    'changing declaration hash cannot add a method');
$snapshot->observe;
is($snapshot->observed, 'void', 'callback sees void context and deleted declaration remains installed');
like(exception(sub { $snapshot->name('extra') }), qr/Too many arguments/,
    'callback signature controls argument arity');

like(exception(sub {
    eval q{package T::Cap::Customer; cap 'Late' => { name => sub { 'late' } }; 1} or die $@;
}), qr/cap list is already sealed/, 'cap declarations are sealed with the owner');
like(exception(sub { T::Cap::Customer::cap('External', 'name') }),
    qr/may only be used inside package/, 'external code cannot declare owner caps');

my $index = 0;
for my $case (
    [q{cap 'Empty'}, qr/expects a name and a hash reference/],
    [q{cap 'Extra' => {}, 'extra'}, qr/expects a name and a hash reference/],
    [q{cap 'Bad::Name' => {}}, qr/Cap name must be an identifier/],
    [q{cap 'Bad' => undef}, qr/expects a hash reference/],
    [q{cap 'Old' => 'name'}, qr/expects a hash reference/],
    [q{cap 'Bad' => []}, qr/expects a hash reference/],
    [q{cap 'Empty' => {}}, qr/must declare at least one method/],
    [q{cap 'Bad' => { 'bad-name' => sub {} }}, qr/Cap method name must be an identifier/],
    [q{cap 'Bad' => { name => undef }}, qr/must be a CODE reference/],
    [q{cap 'Bad' => { name => 'value' }}, qr/must be a CODE reference/],
    [q{cap 'Bad' => { name => {} }}, qr/must be a CODE reference/],
    [q{cap 'Bad' => { as_cap => sub {} }}, qr/reserved method/],
    [q{cap 'Bad' => { DESTROY => sub {} }}, qr/reserved method/],
    [q{cap 'One' => { name => sub {} }; cap 'One' => { name => sub {} }}, qr/already declares cap/],
) {
    my ($compiled, $failure) = define_class('T::Cap::Invalid' . ++$index, $case->[0] . ';');
    ok(!$compiled, "invalid cap declaration $index is rejected");
    like($failure, $case->[1], 'declaration error explains the problem');
}

($ok, $error) = define_class('T::Cap::MissingField', q{
    field 'name'; cap 'Broken' => { missing => sub { value($_[0], 'missing') } };
});
ok($ok, 'callback bodies are not statically inspected') or diag $error;
my $missing = T::Cap::MissingField->new(name => 'Alice')->as_cap('Broken');
like(exception(sub { $missing->missing }), qr/has no field 'missing'/,
    'invalid private field access is checked when callback executes');

{
    package T::Cap::Occupied::Cap::Public;
    sub existing { 1 }
}
($ok, $error) = define_class('T::Cap::Occupied', q{cap 'Public' => { name => sub {} };});
ok(!$ok, 'cap does not overwrite an existing package');
like($error, qr/Cap package .* already exists/, 'namespace collision is explained');

($ok, $error) = define_class('T::Cap::Customer::Cap::Billing', '');
ok(!$ok, 'generated cap cannot be reimported as a full class');
like($error, qr/is a generated cap type/, 'class import reports reserved cap type');
($ok, $error) = define_contract('T::Cap::Customer::Cap::Billing', '');
ok(!$ok, 'generated cap cannot be reimported as a contract');

for my $helper (qw(cap as_cap)) {
    my $class = 'T::Cap::Override' . ++$index;
    local $SIG{__WARN__} = sub {};
    ($ok, $error) = define_class($class, "sub $helper { return }");
    ok($ok, 'helper replacement compiles before finalization') or diag $error;
    like(exception(sub { $class->new }), qr/overrides Elegant::Perl helper/,
        "$helper cannot be replaced by class implementation");
}

# A generated type has no .pm of its own. Resolve it by loading the owner,
# even when no instance or explicit owner import has happened yet.
{
    my $dir = tempdir(CLEANUP => 1);
    open my $file, '>', "$dir/CapLazyOwner.pm" or die $!;
    print {$file} <<'PERL';
package CapLazyOwner;
use Elegant::Perl ':core';
field 'name';
cap 'Public' => { name => sub { value($_[0], 'name') } };
1;
PERL
    close $file or die $!;
    local @INC = ($dir, @INC);
    my $validator = Elegant::Perl::Contract::_compile_validator(
        'CapLazyOwner::Cap::Public', 'T::Cap::Echo',
    );
    my $cap = CapLazyOwner->new(name => 'Lazy')->as_cap('Public');
    ok($validator->{check}->($cap), 'type resolver loads the owner module');
    like(exception(sub {
        Elegant::Perl::Contract::_compile_validator('CapLazyOwner::Cap::Missing', 'T::Cap::Echo');
    }), qr/Unknown Elegant::Perl cap type/, 'unknown cap type has a specific diagnostic');

    # Also exercise normal compilation and CHECK, rather than only runtime
    # eval/require and constructor-triggered finalization used above.
    open $file, '>', "$dir/CapCheckGood.pm" or die $!;
    print {$file} <<'PERL';
package CapCheckGood;
use Elegant::Perl ':core';
cap 'Public' => { name => sub { value($_[0], 'name') } };
field 'name';
1;
PERL
    close $file or die $!;
    open $file, '>', "$dir/CapCheckBad.pm" or die $!;
    print {$file} <<'PERL';
package CapCheckBad;
use Elegant::Perl ':core';
cap 'Public' => { missing => 'not a callback' };
field 'name';
1;
PERL
    close $file or die $!;
    for my $case (
        ['CapCheckGood', 0, qr/checked/],
        ['CapCheckBad', 1, qr/must be a CODE reference/],
    ) {
        my ($module, $fails, $message) = @$case;
        my $script = "BEGIN { open STDERR, '>&', STDOUT or die \$! } use $module; print 'checked'";
        open my $process, '-|', $^X, '-Ilib', "-I$dir", '-e', $script or die $!;
        my $output = do { local $/; <$process> };
        close $process;
        is($? != 0 ? 1 : 0, $fails, "$module has expected compile-time status");
        like($output, $message, "$module is finalized at CHECK without constructing an object");
    }
}

done_testing;
