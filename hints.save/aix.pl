#perl -p -i.bak -e 's#-lutil#/usr/afsws/lib/afs/util.a#' Makefile
$EXTRALIBS =~ s#-lutil#/usr/afsws/lib/afs/util.a#;
