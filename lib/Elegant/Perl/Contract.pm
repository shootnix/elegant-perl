package Elegant::Perl::Contract;

use v5.32;
use strict;
use warnings;

use Elegant::Perl::Error qw(croak location load_module);
use Scalar::Util qw(blessed);
use Sub::Util qw(set_subname subname);
use Types::Standard ();
use Elegant::Perl::Cap ();

our $VERSION = '0.01';

my %CONTRACTS;

#
# Only scalar types are allowed here.
#
# References are deliberately absent from the type universe.
#
my %SCALAR_TYPES = map {
    my $name = $_;

    my $factory =
        Types::Standard->can($name)
        or die "Types::Standard does not provide $name";

    $name => $factory->();

} qw(
    Bool
    Int
    Num
    Str
);


sub import {
    my ($class) = @_;

    my $target = caller;
    croak "$target is a generated cap type" if Elegant::Perl::Cap::_is_cap($target);

    croak
        "$target already uses Elegant::Perl::Contract"
        if exists $CONTRACTS{$target};

    no strict 'refs';

    croak
        "$target already defines MODIFY_CODE_ATTRIBUTES()"
        if defined *{"${target}::MODIFY_CODE_ATTRIBUTES"}{CODE};


    $CONTRACTS{$target} = {
        attributes => {},
        location => location(),
    };


    #
    # Package-local attribute handler.
    #
    # Nothing is installed into UNIVERSAL.
    #
    my $handler = sub {
        my (
            $package,
            $code,
            @attributes,
        ) = @_;
        local $Elegant::Perl::Error::LOCATION = location();

        return _handle_attributes(
            $target,
            $package,
            $code,
            @attributes,
        );
    };


    *{"${target}::MODIFY_CODE_ATTRIBUTES"} =
        set_subname(
            "${target}::MODIFY_CODE_ATTRIBUTES",
            $handler,
        );

    return;
}


sub _handle_attributes {
    my (
        $target,
        $package,
        $code,
        @attributes,
    ) = @_;

    return @attributes unless $package eq $target;
    my $full_name = subname($code);

    croak "Cannot determine contract method name in $target"
        unless defined($full_name)
            && $full_name =~
                /\A\Q$target\E::([A-Za-z_]\w*)\z/;


    my $method = $1;


    my $meta = (
        $CONTRACTS{$target}
            {attributes}
            {$method}
        //= {}
    );
    $meta->{location} //= $Elegant::Perl::Error::LOCATION // location();


    my @unknown;

    for my $attribute (@attributes) {

        #
        # :Builder
        #
        if ($attribute eq 'Builder') {

            _set_method_kind(
                contract => $target,
                method   => $method,
                meta     => $meta,
                kind     => 'Builder',
            );

            next;
        }


        #
        # :Manipulator
        #
        if ($attribute eq 'Manipulator') {

            _set_method_kind(
                contract => $target,
                method   => $method,
                meta     => $meta,
                kind     => 'Manipulator',
            );

            next;
        }


        #
        # :Expects(Int, Money, Self)
        #
        if (
            $attribute =~
                /\AExpects\((.*)\)\z/s
        ) {

            croak
                "$target\::$method declares "
                . ":Expects more than once"
                if exists $meta->{expects};


            my $types =
                _parse_type_list(
                    $target,
                    $method,
                    'Expects',
                    $1,
                );


            croak
                "$target\::$method cannot "
                . "use Void in :Expects"
                if grep {
                    $_ eq 'Void'
                } @$types;


            $meta->{expects} = $types;

            next;
        }


        #
        # :Returns(Str)
        #
        if (
            $attribute =~
                /\AReturns\((.*)\)\z/s
        ) {

            croak
                "$target\::$method declares "
                . ":Returns more than once"
                if exists $meta->{returns};


            my $types =
                _parse_type_list(
                    $target,
                    $method,
                    'Returns',
                    $1,
                );


            croak
                "$target\::$method :Returns "
                . "must contain exactly one type; "
                . "use Void for no return value"
                unless @$types == 1;


            $meta->{returns} =
                $types->[0];

            next;
        }


        #
        # Unknown attribute belongs to Perl / another handler.
        #
        push @unknown, $attribute;
    }


    return @unknown;
}


sub _set_method_kind {
    my (%args) = @_;

    my $contract = $args{contract};
    my $method   = $args{method};
    my $meta     = $args{meta};
    my $kind     = $args{kind};


    if (exists $meta->{kind}) {

        croak
            "$contract\::$method already declares "
            . ":$meta->{kind}; "
            . "a method must be exactly one of "
            . ":Builder or :Manipulator";
    }


    $meta->{kind} = $kind;

    return;
}


sub _parse_type_list {
    my (
        $contract,
        $method,
        $attribute,
        $raw,
    ) = @_;


    $raw =~ s/\A\s+//;
    $raw =~ s/\s+\z//;


    #
    # :Expects()
    #
    return []
        if $raw eq '';


    my @types =
        split /\s*,\s*/,
            $raw,
            -1;


    for my $type (@types) {

        croak
            "$contract\::$method has "
            . "an empty type in :$attribute"
            if $type eq '';


        #
        # Allows:
        #
        #   Str
        #   Self
        #   Money
        #   Domain::Payment
        #
        croak
            "$contract\::$method has "
            . "invalid type '$type' "
            . "in :$attribute"
            unless $type =~
                /\A[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*\z/;
    }


    return \@types;
}


sub _is_contract {
    my ($package) = @_;

    return exists
        $CONTRACTS{$package};
}


#
# Build and validate the structural definition.
#
sub _definition {
    my ($contract) = @_;


    croak
        "$contract is not an Elegant::Perl contract"
        unless exists $CONTRACTS{$contract};

    local $Elegant::Perl::Error::LOCATION = $CONTRACTS{$contract}{location};


    no strict 'refs';


    my %methods;

    my $stash =
        \%{"${contract}::"};


    for my $name (
        keys %$stash
    ) {

        next
            if $name eq
                'MODIFY_CODE_ATTRIBUTES';


        my $code =
            *{"${contract}::$name"}{CODE};


        next unless $code;


        #
        # Ignore imports.
        #
        my $declared_name =
            subname($code);


        next
            unless defined($declared_name)
                && $declared_name
                    eq "${contract}::$name";

        local $Elegant::Perl::Error::LOCATION =
            $CONTRACTS{$contract}{attributes}{$name}{location}
            // $CONTRACTS{$contract}{location};


        #
        # Contract methods are declarations only.
        #
        # Good:
        #
        #     sub foo :Builder :Returns(Str);
        #
        # Bad:
        #
        #     sub foo :Builder :Returns(Str) {
        #         ...
        #     }
        #
        croak
            "$contract\::$name contains implementation; "
            . "contract methods must be declarations only"
            if defined
                &{"${contract}::$name"};


        my $attributes =
            $CONTRACTS{$contract}
                {attributes}
                {$name}
            // {};


        #
        # Every operation must have semantics.
        #
        my $kind =
            $attributes->{kind};


        croak
            "$contract\::$name must declare "
            . "exactly one of :Builder or :Manipulator"
            unless defined $kind;


        my $returns =
            $attributes->{returns};


        #
        # Builder:
        #
        #   - produces something
        #   - therefore must declare a return type
        #   - Void is impossible
        #
        if ($kind eq 'Builder') {

            croak
                "$contract\::$name is a :Builder "
                . "and must declare :Returns(...)"
                unless defined $returns;


            croak
                "$contract\::$name is a :Builder "
                . "and cannot :Returns(Void)"
                if $returns eq 'Void';
        }


        #
        # Manipulator:
        #
        #   - produces no value
        #   - Returns(Void) is implicit
        #
        else {

            croak
                "$contract\::$name is a :Manipulator "
                . "and cannot return '$returns'"
                if defined($returns)
                    && $returns ne 'Void';


            $returns = 'Void';
        }


        $methods{$name} = {
            location => $Elegant::Perl::Error::LOCATION,

            kind =>
                $kind,


            (
                exists $attributes->{expects}

                ? (
                    expects => [
                        @{
                            $attributes->{expects}
                        }
                    ],
                )

                : ()
            ),


            returns =>
                $returns,
        };
    }


    return {
        name    => $contract,
        methods => \%methods,
    };
}


#
# Compile one type into a validator.
#
# This runs during class finalization, not per invocation.
#
sub _compile_validator {
    my (
        $type_name,
        $self_class,
    ) = @_;


    #
    # Any defined non-reference scalar.
    #
    if ($type_name eq 'Scalar') {

        return {
            name => 'Scalar',

            check => sub {
                my ($value) = @_;

                return
                    defined($value)
                    && !ref($value)

                    ? 1
                    : 0;
            },
        };
    }


    #
    # Any blessed Perl object.
    #
    if ($type_name eq 'Object') {

        return {
            name => 'Object',

            check => sub {
                my ($value) = @_;

                return
                    defined blessed($value)

                    ? 1
                    : 0;
            },
        };
    }


    #
    # Exact concrete Elegant::Perl class.
    #
    # No inheritance and no isa().
    #
    if ($type_name eq 'Self') {

        return {
            name => 'Self',

            check => sub {
                my ($value) = @_;

                my $actual =
                    blessed($value);


                return
                    defined($actual)
                    && $actual eq $self_class

                    ? 1
                    : 0;
            },
        };
    }


    #
    # Void is not a value type.
    #
    croak
        "Void is only valid as a return marker"
        if $type_name eq 'Void';
    #
    # Scalar subtype.
    #
    if (
        my $type =
            $SCALAR_TYPES{$type_name}
    ) {
        return {
            name => $type_name,
            check => sub {
                my ($value) = @_;
                #
                # Elegant value universe first.
                #
                return 0
                    unless defined($value)
                        && !ref($value);
                return
                    $type->check($value)
                    ? 1
                    : 0;
            },
        };
    }

    #
    # Generated cap types live in their owner's module, not a separate file.
    # Loading the owner here also supports contracts finalized before owners.
    #
    return Elegant::Perl::Cap::_validator($type_name)
        if Elegant::Perl::Cap::_is_cap($type_name);

    if (!_is_contract($type_name)
        && $type_name =~ /\A(.+)::Cap::[A-Za-z_][A-Za-z0-9_]*\z/) {
        load_module($1, "type '$type_name'");
        croak "Unknown Elegant::Perl cap type '$type_name'"
            unless Elegant::Perl::Cap::_is_cap($type_name);
        return Elegant::Perl::Cap::_validator($type_name);
    }

    # Everything else means <ContractName>.
    #
    # It NEVER means class name.
    #
    unless (
        _is_contract($type_name)
    ) {
        load_module($type_name, "type '$type_name'");
    }

    croak
        "Unknown Elegant::Perl type '$type_name'; "
        . "expected Scalar, Str, Num, Int, Bool, "
        . "Object, Self, Void, "
        . "or an Elegant::Perl contract or cap"
        unless
            _is_contract(
                $type_name
            );

    return {
        name => $type_name,

        check => sub {
            my ($value) = @_;


            return 0
                unless defined
                    blessed($value);

            return
                Elegant::Perl::_object_implements_contract(
                    $value,
                    $type_name,
                )
                ? 1
                : 0;
        },
    };
}

CHECK {
    _definition($_)
        for keys %CONTRACTS;
}


1;
