package Perl::Critic::Policy::ElegantPerl::NoExplicitUndef;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';

use Perl::Critic::Utils qw(
    is_hash_key
);


my $EXPLANATION =
    'Elegant::Perl has no null value. '
    . 'Absence must be represented by an object or domain value.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;

    my $words =
        $document->find(
            'PPI::Token::Word'
        ) || [];


    for my $word (@$words) {
        next
            unless $word->content eq 'undef';

        next
            if is_hash_key($word);


        push @violations,
            $self->violation(
                'Explicit undef is forbidden',
                $EXPLANATION,
                $word,
            );
    }


    return @violations;
}


1;