package Perl::Critic::Policy::ElegantPerl::NoUninitializedVariables;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $EXPLANATION =
    'Elegant::Perl has no undefined values. '
    . 'Lexical variables must be initialized when declared.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;

    my $variables =
        $document->find(
            'PPI::Statement::Variable'
        ) || [];

    for my $statement (@$variables) {
        next unless ($statement->type // '') eq 'my';
        #
        # A declaration is considered initialized only when
        # the declaration itself contains an assignment.
        #
        #
        # Good:
        #
        #   my $foo = 42;
        #   my ($foo, $bar) = @_;
        #
        # Bad:
        #
        #   my $foo;
        #   my ($foo, $bar);
        #
        my $operators = $statement->find('PPI::Token::Operator') || [];
        my $initialized = grep { $_->content eq '=' } @$operators;
        next if $initialized;
        push @violations, $self->violation(
            'Uninitialized lexical variable is forbidden',
            $EXPLANATION,
            $statement,
        );
    }

    return @violations;
}


1;