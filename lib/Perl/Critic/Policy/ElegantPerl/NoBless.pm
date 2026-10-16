package Perl::Critic::Policy::ElegantPerl::NoBless;

use v5.32;
use strict;
use warnings;

use parent 'Elegant::Perl::Critic::Policy';

use Perl::Critic::Utils qw(
    is_hash_key
);


my $EXPLANATION =
    'Elegant::Perl objects must be created exclusively by '
    . 'their generated constructor.';


sub violations_for {
    my ($self, $document) = @_;

    my @violations;
    my $words = $document->find( 'PPI::Token::Word') || [];

    for my $word (@$words) {
        next unless $word->content eq 'bless';
        next if is_hash_key($word);
        push @violations, $self->violation(
            'Direct bless is forbidden',
            $EXPLANATION,
            $word,
        );
    }

    return @violations;
}


1;