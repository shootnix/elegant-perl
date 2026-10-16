use v5.32;
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Elegant::Perl',
    VERSION_FROM     => 'lib/Elegant/Perl.pm',
    ABSTRACT         => 'Opinionated object and contract framework for Perl 5.32+',
    MIN_PERL_VERSION => '5.032',
    LICENSE          => 'unknown',
    EXE_FILES        => ['bin/elegant-perl'],
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        release_status => 'testing',
    },
    PREREQ_PM        => {
        'Feature::Compat::Defer' => 0,
        'Feature::Compat::Try'   => 0,
        'Import::Into'           => 0,
        'Module::Runtime'        => 0,
        'Perl::Critic'           => 0,
        'Types::Standard'        => 0,
    },
    TEST_REQUIRES    => {
        'Test::More' => 0,
    },
);
