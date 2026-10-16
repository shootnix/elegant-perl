package Perl::Critic::Policy::ElegantPerl::NoMethodValue;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $EXPLANATION =
    'value() is private implementation infrastructure '
    . 'and must only be called as value($self, ...).';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;

    my $words =
        $document->find(
            'PPI::Token::Word'
        ) || [];


    for my $word (@$words) {
        my $name =
            $word->content;


        #
        # Currency::value(...)
        #
        if (
            $name =~
                /(?:\A|::)value\z/
            && $name ne 'value'
        ) {
            push @violations,
                $self->violation(
                    'Qualified value() call is forbidden',
                    $EXPLANATION,
                    $word,
                );

            next;
        }


        next
            unless $name eq 'value';


        #
        # $self->value(...)
        #
        my $previous =
            $word->sprevious_sibling;

        next
            unless $previous;

        next
            unless $previous->isa(
                'PPI::Token::Operator'
            );

        next
            unless $previous->content eq '->';


        push @violations,
            $self->violation(
                'value() must not be called as a method',
                $EXPLANATION,
                $word,
            );
    }


    return @violations;
}


1;