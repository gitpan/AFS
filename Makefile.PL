use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

require 'version';

# provide the POD documentation
mkdir('./lib');
mkdir('./lib/AFS');
system("cp ./pod/v2/afsperl.pod lib/AFS.pod");
system("cp ./pod/v2/afsperlacl.pod lib/AFS/ACL.pod");
system("cp ./pod/v2/afsperlbase.pod lib/AFS/Base.pod");
system("cp ./pod/v2/afsperlbos.pod lib/AFS/BOS.pod");
system("cp ./pod/v2/afsperlcell.pod lib/AFS/Cell.pod");
system("cp ./pod/v2/afsperlcm.pod lib/AFS/CM.pod");
system("cp ./pod/v2/afsperlfs.pod lib/AFS/FS.pod");
system("cp ./pod/v2/afsperlkas.pod lib/AFS/KAS.pod");
system("cp ./pod/v2/afsperlktck.pod lib/AFS/KTC_EKEY.pod");
system("cp ./pod/v2/afsperlktcp.pod lib/AFS/KTC_PRINCIPAL.pod");
system("cp ./pod/v2/afsperlktct.pod lib/AFS/KTC_TOKEN.pod");
system("cp ./pod/v2/afsperlpts.pod lib/AFS/PTS.pod");
system("cp ./pod/v2/afsperlutils.pod lib/AFS/Utils.pod");
system("cp ./pod/v2/afsperlvldb.pod lib/AFS/VLDB.pod");
system("cp ./pod/v2/afsperlvos.pod lib/AFS/VOS.pod");

WriteMakefile(
              'NAME'         => 'AFS',
              'VERSION'      => $VERSION,
              ($] >= 5.005 ?
               ('AUTHOR'   => 'Norbert E Gruener <nog@MPA-Garching.MPG.de>',
                'ABSTRACT' => 'Perl interface to AFS programming APIs') : () ),
              'realclean'  => {FILES => 'Makefile.bak pod/v2/*.html pod/v2/pod2htm* lib'},
             );

sub MY::postamble {
        '
html: Makefile
	cd pod/v2 && $(MAKE) html

pod: blib
	cp pod/v2/afsperl.pod blib/lib/AFS.pod
	cp pod/v2/afsperlacl.pod blib/lib/AFS/ACL.pod
	cp pod/v2/afsperlbase.pod blib/lib/AFS/BASE.pod
	cp pod/v2/afsperlbos.pod blib/lib/AFS/BOS.pod
	cp pod/v2/afsperlcell.pod blib/lib/AFS/CELL.pod
	cp pod/v2/afsperlcm.pod blib/lib/AFS/CM.pod
	cp pod/v2/afsperlfs.pod blib/lib/AFS/FS.pod
	cp pod/v2/afsperlkas.pod blib/lib/AFS/KAS.pod
	cp pod/v2/afsperlktck.pod blib/lib/AFS/KTC_EKEY.pod
	cp pod/v2/afsperlktcp.pod blib/lib/AFS/KTC_PRINCIPAL.pod
	cp pod/v2/afsperlktct.pod blib/lib/AFS/KTC_TOKEN.pod
	cp pod/v2/afsperlpts.pod blib/lib/AFS/PTS.pod
	cp pod/v2/afsperlutils.pod blib/lib/AFS/Utils.pod
	cp pod/v2/afsperlvldb.pod blib/lib/AFS/VLDB.pod
	cp pod/v2/afsperlvos.pod blib/lib/AFS/VOS.pod
';
}

