package Perl::Critic::Policy::ElegantPerl::FieldLimit;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $MAX_FIELDS = 5;


my $EXPLANATION =
    'Elegant objects should encapsulate a small coherent state. '
    . 'A large field set usually indicates multiple responsibilities.';


sub violations_for {
    my ($self, $document) = @_;

    my @fields;

    my $words =
        $document->find(
            'PPI::Token::Word'
        ) || [];


    for my $word (@$words) {
        next
            unless $word->content eq 'field';


        #
        # Ignore:
        #
        #   $object->field(...)
        #   Foo::field(...)
        #
        my $previous =
            $word->sprevious_sibling;


        if ($previous) {
            next
                if $previous->isa(
                    'PPI::Token::Operator'
                )
                && $previous->content eq '->';

            next
                if $previous->isa(
                    'PPI::Token::Word'
                );
        }


        push @fields,
            $word;
    }


    return
        if @fields <= $MAX_FIELDS;


    return $self->violation(
        sprintf(
            'Object declares %d fields; maximum is %d',
            scalar(@fields),
            $MAX_FIELDS,
        ),
        $EXPLANATION,
        $fields[$MAX_FIELDS],
    );
}


1;