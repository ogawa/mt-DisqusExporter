use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'DisqusExporter',
    VERSION_FROM => 'tools/disqus-exporter.pl',
    DISTNAME => 'DisqusExporter',
    EXE_FILES => [ 'tools/disqus-exporter.pl' ],
);
