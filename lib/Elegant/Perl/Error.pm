package Elegant::Perl::Error;

use v5.32;
use strict;
use warnings;
use Exporter qw(import);
use Module::Runtime qw(require_module);

our @EXPORT_OK = qw(croak location load_module invoke);

# Deferred validation can run at CHECK, when the declaration is no longer on
# the stack. Callers scope this to a saved declaration location during checks.
our $LOCATION;

sub location {
    my $depth = 0;
    while (my @frame = caller($depth++)) {
        next if $frame[0] =~ /\AElegant::Perl(?:\z|::)/;
        next if $frame[0] eq 'attributes';
        return { file => $frame[1], line => $frame[2] };
    }
    return { file => $0, line => 1 };
}

sub croak {
    my $message = join '', @_;
    my $site = $LOCATION // location();
    $message =~ s/\n\z//;
    die "$message at $site->{file} line $site->{line}.\n";
}

sub load_module {
    my ($module, $reason) = @_;
    my $ok = eval { require_module($module); 1 };
    return if $ok;
    my $error = $@;
    (my $file = "$module.pm") =~ s{::}{/}g;
    croak "Can't locate $file" . (defined($reason) ? " (required for $reason)" : '')
        if $error =~ /\ACan't locate \Q$file\E in \@INC/;
    # Preserve exceptions originating in the loaded module itself.
    die $error;
}

# Contract wrappers must inspect results, so unlike caps they cannot tail-call
# implementations. Relocate only native signature-binding errors at this
# boundary; exceptions from inside user code retain their original location.
sub invoke {
    my ($code, @args) = @_;
    my $context = wantarray;
    my ($result, @results);
    local $@;
    my $ok = eval {
        if (!defined $context) {
            $code->(@args);
        } elsif ($context) {
            @results = $code->(@args);
        } else {
            $result = $code->(@args);
        }
        1;
    };
    if (!$ok) {
        my $error = $@;
        my $file = __FILE__;
        if (!ref($error) && $error =~ /\AToo (?:many|few) arguments for subroutine/
            && $error =~ s/ at \Q$file\E line \d+\.\n\z//) {
            croak $error;
        }
        die $error;
    }
    return unless defined $context;
    return $context ? @results : $result;
}

1;
