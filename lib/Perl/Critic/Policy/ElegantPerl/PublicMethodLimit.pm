package Perl::Critic::Policy::ElegantPerl::PublicMethodLimit;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';


my $MAX = 5;

my $EXPLANATION =
    'Elegant objects expose a very small public API. '
    . 'Split responsibilities or introduce another object.';

sub violations_for {
    my ($self, $document) = @_;

    my $subs = $document->find('PPI::Statement::Sub') || [];
    my @public;
    for my $sub (@$subs) {
        my $name = $sub->name;
        next unless defined $name;
        #
        # Forward declarations belong to contracts,
        # but contract files do not use Elegant::Perl anyway.
        #
        next unless $sub->block;
        #
        # A lexical named sub is not a public package method.
        #
        my $type = $sub->type;
        next if defined($type) && ($type eq 'my' || $type eq 'state');
        #
        # Generated new() does not exist in source.
        # DESTROY is infrastructure.
        #
        next if $name eq 'DESTROY';
        push @public, $sub;
    }

    return if @public <= $MAX;

    my $element = $public[$MAX];

    return $self->violation(
        sprintf(
            'Object has %d public methods; maximum is %d',
            scalar(@public),
            $MAX,
        ),
        $EXPLANATION,
        $element,
    );
}


1;