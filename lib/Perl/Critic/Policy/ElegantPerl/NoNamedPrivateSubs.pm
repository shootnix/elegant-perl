package Perl::Critic::Policy::ElegantPerl::NoNamedPrivateSubs;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $EXPLANATION =
    'Named package subs are public behaviour. '
    . 'Private implementation must use lexical coderefs.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;
    my $subs = $document->find('PPI::Statement::Sub') || [];

    for my $sub (@$subs) {
        my $name = $sub->name;
        next unless defined $name;
        next unless $name =~ /^_/;

        push @violations, $self->violation(
            "Named private sub '$name' is forbidden",
            $EXPLANATION,
            $sub,
        );
    }

    return @violations;
}


1;