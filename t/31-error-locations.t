use v5.32;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);

my $dir = tempdir(CLEANUP => 1);

sub write_module {
    my ($name, $source) = @_;
    my $path = "$dir/$name.pm";
    open my $file, '>', $path or die $!;
    print {$file} $source;
    close $file or die $!;
    return $path;
}

my $index = 0;
sub run_case {
    my ($source) = @_;
    my $path = "$dir/case-" . ++$index . '.pl';
    open my $file, '>', $path or die $!;
    print {$file} "BEGIN { open STDERR, '>&', STDOUT or die \$! }\n", $source;
    close $file or die $!;
    open my $process, '-|', $^X, '-Ilib', "-I$dir", $path or die $!;
    my $output = do { local $/; <$process> };
    close $process;
    return ($output, $? >> 8, $path);
}

sub check_location {
    my ($output, $status, $file, $line, $message) = @_;
    isnt($status, 0, "$message fails as expected");
    like($output, qr/ at \Q$file\E line $line\./, "$message points to user code");
    unlike($output, qr{(?:lib/|lib\\)Elegant(?:/|\\)Perl}, "$message does not point inside the framework");
}

write_module('DiagnosticContract', <<'PERL');
package DiagnosticContract;
use Elegant::Perl::Contract;
sub echo :Builder :Expects(Int) :Returns(Int);
sub bad :Builder :Expects() :Returns(Int);
1;
PERL
my $class_file = write_module('DiagnosticExample', <<'PERL');
package DiagnosticExample;
use Elegant::Perl ':core';
implements 'DiagnosticContract';
field 'count' => 'Int';
cap 'Public' => {
    missing => sub { value($_[0], 'missing') },
    explode => sub { die "original user exception\n" },
};
sub echo { $_[1] }
sub bad { 'wrong return type' }
1;
PERL

write_module('DiagnosticSignatures', <<'PERL');
package DiagnosticSignatures;
use Elegant::Perl ':signatures';
implements 'DiagnosticContract';
sub echo ($self, $number, $extra) { $number }
sub bad ($self) { 1 }
cap 'Public' => { strict => sub ($self) { 1 } };
1;
PERL

for my $case (
    ["use DiagnosticExample;\nDiagnosticExample->new(count => 'wrong');\n", 3, qr/field 'count' does not satisfy Int/, 'constructor type error'],
    ["use DiagnosticExample;\nDiagnosticExample->new(count => []);\n", 3, qr/must contain a defined scalar/, 'constructor value error'],
    ["use DiagnosticExample;\nmy \$obj = DiagnosticExample->new(count => 1);\n\$obj->echo('wrong');\n", 4, qr/argument 1 does not satisfy Int/, 'method argument error'],
    ["use DiagnosticExample;\nmy \$obj = DiagnosticExample->new(count => 1);\nmy \$bad = \$obj->bad;\n", 4, qr/return value does not satisfy Int/, 'method return error'],
    ["use DiagnosticExample;\nDiagnosticExample->new(count => 1)->as_cap('Missing');\n", 3, qr/has no cap 'Missing'/, 'unknown cap error'],
    ["use DiagnosticExample;\nDiagnosticExample->new(count => 1)->as_cap('Public')->missing;\n", 6, qr/has no field 'missing'/, 'private field error inside callback'],
    ["use DiagnosticSignatures;\nDiagnosticSignatures->new->echo(1);\n", 3, qr/Too few arguments for subroutine/, 'implementation signature error'],
    ["use DiagnosticSignatures;\nDiagnosticSignatures->new->as_cap('Public')->strict('extra');\n", 3, qr/Too many arguments for subroutine/, 'cap signature error'],
) {
    my ($script, $line, $pattern, $name) = @$case;
    my ($output, $status, $path) = run_case($script);
    like($output, $pattern, "$name retains its diagnostic");
    check_location($output, $status, $name eq 'private field error inside callback' ? $class_file : $path,
        $line, $name);
}

my $field_file = write_module('DiagnosticBadField', <<'PERL');
package DiagnosticBadField;
use Elegant::Perl ':core';
field 'count' => 'MissingDiagnosticType';
1;
PERL
my ($output, $status) = run_case("use DiagnosticBadField;\n");
like($output, qr/Can't locate MissingDiagnosticType.pm/, 'missing type diagnostic is preserved');
check_location($output, $status, $field_file, 3, 'field type resolution at CHECK');

my $contract_file = write_module('DiagnosticBadContract', <<'PERL');
package DiagnosticBadContract;
use Elegant::Perl::Contract;
sub number
    :Builder
    :Returns(MissingDiagnosticType);
1;
PERL
write_module('DiagnosticBadImplementation', <<'PERL');
package DiagnosticBadImplementation;
use Elegant::Perl ':core';
implements 'DiagnosticBadContract';
sub number { 1 }
1;
PERL
($output, $status) = run_case("use DiagnosticBadImplementation;\n");
like($output, qr/Can't locate MissingDiagnosticType.pm/, 'contract type resolution diagnostic is preserved');
check_location($output, $status, $contract_file, 5, 'contract type resolution at CHECK');

my $semantic_file = write_module('DiagnosticSemanticContract', <<'PERL');
package DiagnosticSemanticContract;
use Elegant::Perl::Contract;
sub number :Builder;
1;
PERL
($output, $status) = run_case("use DiagnosticSemanticContract;\n");
like($output, qr/must declare :Returns/, 'contract semantic error is preserved');
check_location($output, $status, $semantic_file, 3, 'contract semantic validation at CHECK');

my $cap_file = write_module('DiagnosticBadCap', <<'PERL');
package DiagnosticBadCap;
use Elegant::Perl ':core';
cap 'Public' => { name => 'not code' };
1;
PERL
($output, $status) = run_case("use DiagnosticBadCap;\n");
like($output, qr/must be a CODE reference/, 'cap declaration error is preserved');
check_location($output, $status, $cap_file, 3, 'cap declaration error');

my $missing_contract_file = write_module('DiagnosticMissingContract', <<'PERL');
package DiagnosticMissingContract;
use Elegant::Perl ':core';
implements 'MissingDiagnosticContract';
1;
PERL
($output, $status) = run_case("use DiagnosticMissingContract;\n");
like($output, qr/Can't locate MissingDiagnosticContract.pm/, 'missing contract diagnostic is preserved');
check_location($output, $status, $missing_contract_file, 3, 'missing contract error');

($output, $status) = run_case("use DiagnosticExample;\nDiagnosticExample->new(count => 1)->as_cap('Public')->explode;\n");
is($output, "original user exception\n", 'user callback exceptions are not rewritten');
isnt($status, 0, 'user callback exception still fails');

write_module('DiagnosticThrows', <<'PERL');
package DiagnosticThrows;
use Elegant::Perl ':core';
implements 'DiagnosticContract';
sub echo { die "original method exception\n" }
sub bad { 1 }
1;
PERL
($output, $status) = run_case("use DiagnosticThrows;\nDiagnosticThrows->new->echo(1);\n");
is($output, "original method exception\n", 'contract implementation exceptions are not rewritten');
isnt($status, 0, 'contract implementation exception still fails');

done_testing;
