use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
              'NAME'         => 'AFS',
              'VERSION_FROM' => 'version',
              ($] >= 5.005 ?
               ('AUTHOR'   => 'Norbert E Gruener <nog@MPA-Garching.MPG.de>',
                'ABSTRACT' => 'Perl interface to AFS programming APIs') : () ),
             );
