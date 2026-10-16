package Perl::Critic::Policy::ElegantPerl::NoTypeIntrospection;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';

use Perl::Critic::Utils qw(
    is_hash_key
);


my %FORBIDDEN = map {
    $_ => 1
} qw(
    ref
    blessed
    reftype
    refaddr
    isa
    can
    DOES
);


my $EXPLANATION =
    'Behaviour must be selected through contracts and polymorphism, '
    . 'not runtime type inspection.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;

    my $words =
        $document->find(
            'PPI::Token::Word'
        ) || [];


    for my $word (@$words) {
        next
            if is_hash_key($word);

        my $name =
            $word->content;

        my ($short) =
            $name =~
                /(?:\A|::)([A-Za-z_]\w*)\z/;

        next
            unless defined $short
                && $FORBIDDEN{$short};


        push @violations,
            $self->violation(
                "Type introspection '$name' is forbidden",
                $EXPLANATION,
                $word,
            );
    }


    return @violations;
}


1;