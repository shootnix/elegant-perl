use v5.32;
use strict;
use warnings;

use Test::More;
use PPI;
use Perl::Critic;
use Module::Runtime qw(require_module);
use File::Temp qw(tempdir);
use Elegant::Perl::Critic::Util qw(is_elegant_document);

# PPI returns false (the empty string), not necessarily undef, on no matches.
# Exercise each policy directly so its early Elegant-document guard cannot
# mask an unsafe dereference of an empty search result.
my $plain = '1;';
my $document = PPI::Document->new(\$plain);
ok(!is_elegant_document($document), 'document without includes is safely ignored');

for my $name (qw(
    FieldLimit NoBless NoCustomConstructor NoExplicitUndef NoGlobalMutableState
    NoInheritance NoMethodValue NoNamedPrivateSubs NoStaticDispatch
    NoTypeIntrospection NoUninitializedVariables PublicMethodLimit
)) {
    my $class = "Perl::Critic::Policy::ElegantPerl::$name";
    require_module($class);
    my @violations = $class->new->violations_for($document);
    is(scalar @violations, 0, "$name handles missing PPI nodes");
}

my $critic = Perl::Critic->new(-theme => 'elegantperl');
my $clean = <<'PERL';
package Example::Clean;
use Elegant::Perl ':core';
field 'name';
1;
PERL
my @violations = $critic->critique(\$clean);
is(scalar @violations, 0, 'all policies handle an Elegant class without named subs or variables');

my $constructor = <<'PERL';
package Example::BadConstructor;
use Elegant::Perl ':core';
sub new { return 1 }
1;
PERL
@violations = $critic->critique(\$constructor);
ok(scalar(grep { $_->policy =~ /::NoCustomConstructor\z/ } @violations),
    'constructor policy still detects an actual violation');

my $uninitialized = <<'PERL';
package Example::Uninitialized;
use Elegant::Perl ':core';
my $item;
1;
PERL
@violations = $critic->critique(\$uninitialized);
ok(scalar(grep { $_->policy =~ /::NoUninitializedVariables\z/ } @violations),
    'variable without operator nodes is reported instead of crashing');

my $dir = tempdir(CLEANUP => 1);
for my $case (
    ['clean.pm', $clean, 0, qr/\A\z/],
    ['constructor.pm', $constructor, 1, qr/Custom new\(\) is forbidden/],
) {
    my ($name, $source, $status, $message) = @$case;
    my $path = "$dir/$name";
    open my $file, '>', $path or die $!;
    print {$file} $source;
    close $file or die $!;
    open my $process, '-|', $^X, '-Ilib', 'bin/elegant-perl', 'check', $path or die $!;
    my $output = do { local $/; <$process> };
    close $process;
    is($? >> 8, $status, "CLI returns expected status for $name");
    like($output // '', $message, "CLI returns expected diagnostics for $name");
}

done_testing;
