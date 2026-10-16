package Elegant::Perl::Critic::Policy;

use v5.32;
use strict;
use warnings;

use parent 'Perl::Critic::Policy';

use Perl::Critic::Utils qw(
    :severities
);

use Elegant::Perl::Critic::Util qw(
    is_elegant_document
);


sub applies_to {
    return 'PPI::Document';
}


sub supported_parameters {
    return;
}


sub default_severity {
    return $SEVERITY_HIGHEST;
}


sub default_themes {
    return qw(
        elegantperl
    );
}


sub violates {
    my ($self, $document) = @_;

    return
        unless is_elegant_document(
            $document
        );

    return $self->violations_for(
        $document
    );
}


sub violations_for {
    die 'violations_for() must be implemented';
}


1;