package Elegant::Perl::Critic::Util;

use v5.32;
use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
    is_elegant_document
);


sub is_elegant_document {
    my ($document) = @_;

    my $includes =
        $document->find(
            'PPI::Statement::Include'
        ) || [];

    for my $include (@$includes) {
        next
            unless ($include->type // '') eq 'use';

        next
            unless ($include->module // '')
                eq 'Elegant::Perl';

        return 1;
    }

    return 0;
}


1;