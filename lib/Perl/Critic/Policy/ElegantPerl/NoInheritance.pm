package Perl::Critic::Policy::ElegantPerl::NoInheritance;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $EXPLANATION =
    'Elegant::Perl objects use contracts and composition, '
    . 'not implementation inheritance.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;


    #
    # use parent ...
    # use base ...
    #
    my $includes =
        $document->find(
            'PPI::Statement::Include'
        ) || [];

    for my $include (@$includes) {
        next
            unless ($include->type // '') eq 'use';

        my $module =
            $include->module // '';

        next
            unless $module eq 'parent'
                || $module eq 'base';

        push @violations,
            $self->violation(
                "Inheritance via '$module' is forbidden",
                $EXPLANATION,
                $include,
            );
    }


    #
    # @ISA
    # @Foo::ISA
    #
    my $symbols =
        $document->find(
            'PPI::Token::Symbol'
        ) || [];

    for my $symbol (@$symbols) {
        my $name =
            $symbol->content;

        next
            unless $name =~
                /\A\@(?:[A-Za-z_]\w*::)*ISA\z/;

        push @violations,
            $self->violation(
                '@ISA is forbidden',
                $EXPLANATION,
                $symbol,
            );
    }


    return @violations;
}


1;