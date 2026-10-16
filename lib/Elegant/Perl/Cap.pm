package Elegant::Perl::Cap;

use v5.32;
use strict;
use warnings;

use Elegant::Perl::Error qw(croak);
use Hash::Util::FieldHash qw(fieldhash);
use Scalar::Util qw(blessed);
use Sub::Util qw(set_subname);

our $VERSION = '0.01';

my %CAPS;

my %RESERVED = map { $_ => 1 } qw(
    new as_cap field value cap implements DESTROY AUTOLOAD
    can isa DOES VERSION import unimport
);

# Cap packages are generated, not user-defined Elegant classes. Each cap
# retains its source in private state. Only the declared callbacks are exposed.
sub _declare {
    my ($owner, $name, $cap_hash) = @_;
    my $type = "${owner}::Cap::$name";

    croak "$owner already declares cap '$name'" if exists $CAPS{$type};
    croak "$type expects a hash reference of methods" unless ref($cap_hash) eq 'HASH';
    croak "$type must declare at least one method" unless keys %$cap_hash;

    # Snapshot the declaration: retaining and changing the input hash must not
    # change an already declared cap's interface or implementations.
    my %methods = %$cap_hash;
    no strict 'refs';
    croak "Cap package $type already exists" if keys %{"${type}::"};

    for my $method (sort keys %methods) {
        croak 'Cap method name must be an identifier'
            unless $method =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
        croak "$type cannot expose reserved method '$method'" if $RESERVED{$method};
        croak "$type method '$method' must be a CODE reference"
            unless ref($methods{$method}) eq 'CODE';
    }

    fieldhash my %sources;
    for my $method (sort keys %methods) {
        my $implementation = $methods{$method};
        my $wrapper = sub {
            my ($self, @args) = @_;
            croak "Invalid $type cap"
                unless (blessed($self) // '') eq $type && exists $sources{$self};
            # Tail-call user code so Perl's own signature errors also point
            # to the user's invocation rather than this generated wrapper.
            @_ = ($sources{$self}, @args);
            goto &$implementation;
        };
        *{"${type}::$method"} = set_subname("${type}::$method", $wrapper);
    }

    $CAPS{$type} = {
        check => sub {
            my ($value) = @_;
            return (blessed($value) // '') eq $type && exists $sources{$value};
        },
    };
    # Keep the issuer in the owner's lexical state, not a global factory.
    return sub {
        my ($source) = @_;
        my $identity;
        my $self = bless \$identity, $type;
        $sources{$self} = $source;
        return $self;
    };
}

sub _is_cap {
    my ($type) = @_;
    return exists $CAPS{$type};
}

sub _validator {
    my ($type) = @_;
    return { name => $type, check => $CAPS{$type}{check} };
}

1;
