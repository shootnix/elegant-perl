package Perl::Critic::Policy::ElegantPerl::NoGlobalMutableState;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $EXPLANATION =
    'Elegant objects must not depend on mutable package '
    . 'or persistent lexical state.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;


    #
    # our
    # state
    # local
    #
    my $variables =
        $document->find(
            'PPI::Statement::Variable'
        ) || [];


    for my $statement (@$variables) {
        my $type =
            $statement->type // '';

        next
            unless $type eq 'our'
                || $type eq 'state'
                || $type eq 'local';


        push @violations,
            $self->violation(
                "Variable declaration '$type' is forbidden",
                $EXPLANATION,
                $statement,
            );
    }


    #
    # Direct package variable access:
    #
    #   $Foo::bar
    #   @Foo::items
    #   %Foo::cache
    #
    my $symbols =
        $document->find(
            'PPI::Token::Symbol'
        ) || [];


    for my $symbol (@$symbols) {
        my $name =
            $symbol->content;


        #
        # No duplicate with NoInheritance.
        #
        next
            if $name =~
                /\@(?:[A-Za-z_]\w*::)*ISA\z/;


        next
            unless $name =~
                /\A[\$\@\%](?:[A-Za-z_]\w*::)+[A-Za-z_]\w*\z/;


        push @violations,
            $self->violation(
                "Package variable '$name' is forbidden",
                $EXPLANATION,
                $symbol,
            );
    }


    #
    # Particularly common mutable Perl globals.
    #
    my %globals = map {
        $_ => 1
    } qw(
        %ENV
        %SIG
        @ARGV
    );


    for my $symbol (@$symbols) {
        my $name =
            $symbol->content;

        next
            unless $globals{$name};

        push @violations,
            $self->violation(
                "Global '$name' is forbidden",
                $EXPLANATION,
                $symbol,
            );
    }


    return @violations;
}


1;