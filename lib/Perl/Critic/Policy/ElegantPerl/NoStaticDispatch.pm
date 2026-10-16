package Perl::Critic::Policy::ElegantPerl::NoStaticDispatch;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';

use Perl::Critic::Utils qw(
    :classification
);


my $EXPLANATION =
    'Elegant::Perl forbids static behaviour. '
    . 'Public behaviour must be invoked on objects. '
    . 'The only permitted class-level call is generated new().';


sub violations_for {
    my ($self, $document) = @_;

    return if is_adapter_document($document);

    my @violations;

    my $words =
        $document->find(
            'PPI::Token::Word'
        ) || [];


    for my $word (@$words) {

        #
        # Foo::bar(...)
        #
        # Foo::Bar::bar(...)
        #
        # Qualified function calls are static behaviour.
        #
        if (
            is_qualified_name($word)
            && is_function_call($word)
        ) {
            push @violations,
                $self->violation(
                    "Static call '$word' is forbidden",
                    $EXPLANATION,
                    $word,
                );

            next;
        }


        #
        # Foo->bar(...)
        # Foo::Bar->bar(...)
        #
        # Perl::Critic already knows how to recognize a
        # bareword followed by -> as a class name.
        #
        next
            unless is_class_name($word);


        my $operator =
            $word->snext_sibling;

        next
            unless $operator
                && $operator->isa(
                    'PPI::Token::Operator'
                )
                && $operator->content eq '->';


        my $method =
            $operator->snext_sibling;

        next
            unless $method
                && $method->isa(
                    'PPI::Token::Word'
                );


        #
        # The generated constructor is the only
        # legitimate class-level operation.
        #
        next
            if $method->content eq 'new';


        push @violations,
            $self->violation(
                sprintf(
                    "Static method call '%s->%s' is forbidden",
                    $word->content,
                    $method->content,
                ),
                $EXPLANATION,
                $word,
            );
    }


    return @violations;
}

sub is_adapter_document {
    my ($document) = @_;

    my $packages =
        $document->find(
            'PPI::Statement::Package'
        ) || [];

    for my $package (@$packages) {
        my $name =
            $package->namespace;

        next
            unless defined $name;

        return 1
            if $name =~
                /(?:\A|::)Adapter::/;
    }

    return 0;
}


1;