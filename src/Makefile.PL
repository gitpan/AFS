#------------------------------------------------------------------------------
# RCS-Id: "@(#)Makefile.PL,v 1.9 2002/07/02 07:31:25 nog Exp"
#
# Copyright © 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use ExtUtils::MakeMaker;

# set XS version to sync the PM-Version and the XS-Version
$XS_VERSION = do{my@r=q/V_2_0/=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

# give me the path to the AFS system libraries
# used to build the AFS extension module
my $AFSPath = $ENV{AFSPATH} || '/usr/afsws';
print "Which AFS system libraries should be used? [$AFSPath] ";
my $answer = <STDIN>;
if ($answer ne "\n") { chomp($AFSPath = $answer); }
print "\n";


# find out the AFS version of the AFS system libraries
open FILE, ">fotav.c";
print FILE <<'EOF';
int main(void)
{
  extern char *AFSVersion;
  printf(">%s<\n",AFSVersion);
}
EOF
close FILE;

system ("cc  fotav.c -L$AFSPath/lib -lubik");
if ($CHILD_ERROR) { die "\nCould not compile test code to retrieve the version of AFS system libraries...\n"; }
my $version = `./a.out` || die "\nCould not run test code to retrieve the version of AFS system libraries...\n";
unlink 'a.out', 'fotav.c';
print "AFS Version = $version \n";

# set the compiler flag "-D$version" according to the AFS version
my $d_flag = '';
if ($version =~ /3.4/)    { $d_flag = 'AFS 3.4'; }
elsif ($version =~ /3.5/) { $d_flag = 'AFS 3.5'; }
elsif ($version =~ /3.6/) { $d_flag = 'AFS 3.6'; }
elsif ($version =~ /1.0/) { $d_flag = 'OpenAFS 1.0'; }
elsif ($version =~ /1.1/) { $d_flag = 'OpenAFS 1.1'; }
elsif ($version =~ /1.2/) { $d_flag = 'OpenAFS 1.2'; }

$version = $d_flag;
$d_flag =~ tr/\. /__/;
$d_flag = '-D'.$d_flag;


# determine the alpha_sys value
#my $alpha_sys = 'i386_linux24';
my $alpha_sys = `$AFSPath/bin/fs sysname` || die "No alpha_sys ... \n";
$alpha_sys =~ s/Current sysname is:? //;
$alpha_sys =~ s/list? //;
$alpha_sys =~ /(\w+)/;
$alpha_sys = $1;


# print out a summary of determined data
print "Your AFS system library is located at:  $AFSPath \n";
print "              and it is major version:  $version \n";
print "Your AFS system type seems to be:       $alpha_sys \n\n";


# now create the Makefile
if ($alpha_sys eq 'rs_aix42' or
    $alpha_sys eq 'rs_aix41' or
    $alpha_sys eq 'rs_aix32' or

    $alpha_sys eq 'sgi_65') {
    WriteMakefile(
                  'NAME'         => 'AFS',
                  'VERSION_FROM' => 'AFS.pm',
                  'XS_VERSION'   => "$XS_VERSION",
                  'LIBS'	 => ["-L$AFSPath/lib -L$AFSPath/lib/afs -lkauth -lprot -lubik -lauth -lrxkad -lsys -ldes -lrx -llwp -lcom_err -lutil -laudit"],
                  'DEFINE'	 => "$d_flag",
                  'INC'          => "-I$AFSPath/include",
#                    'CC'           => 'gcc',   # muss ich testen ob noetig auf AIX oder SGI ???
#                    'LD'           => 'gcc',
#                    'CCCDLFLAGS'   => '-fPIC',
                 );
}
elsif ($alpha_sys eq 'sun4x_55' or
       $alpha_sys eq 'sun4x_56' or
       $alpha_sys eq 'sun4x_57' or
       $alpha_sys eq 'sun4x_58') {
    WriteMakefile(
                  'NAME'         => 'AFS',
                  'VERSION_FROM' => 'AFS.pm',
                  'XS_VERSION'   => "$XS_VERSION",
                  'LIBS'	 => ["-L$AFSPath/lib -L$AFSPath/lib/afs -lkauth -lprot -lubik -lauth -lrxkad -lsys -ldes -lrx -llwp -lcom_err -lutil -laudit -L/usr/ucblib -lucb"],
                  'DEFINE'	 => "$d_flag",
                  'INC'          => "-I$AFSPath/include",
                  'CC'           => 'gcc',
                  'LD'           => 'gcc',
                  'CCCDLFLAGS'   => '-fPIC',
                 );
}
elsif ($alpha_sys eq 'i386_linux22' or
       $alpha_sys eq 'i386_linux24') {
    WriteMakefile(
                  'NAME'         => 'AFS',
                  'VERSION_FROM' => 'AFS.pm',
                  'XS_VERSION'   => "$XS_VERSION",
                  'LIBS'	 => ["-L$AFSPath/lib -L$AFSPath/lib/afs -lkauth -lrx -lprot -lubik -lauth -lrxkad -lsys -ldes -llwp -lcom_err -lutil -laudit -lvolser -lvldb -lcmd -lrx -lresolv"],
                  'DEFINE'	 => "$d_flag",
                  'INC'          => "-I$AFSPath/include",
                 );
}
elsif ($alpha_sys eq 'alpha_dux40' ) {
    WriteMakefile(
                  'NAME'         => 'AFS',
                  'VERSION_FROM' => 'AFS.pm',
                  'XS_VERSION'   => "$XS_VERSION",
                  'LIBS'         => ["-L$AFSPath/lib -L$AFSPath/lib/afs -lkauth -lprot -lubik -lauth -lrxkad -lsys -ldes -lrx -llwp -lcom_err -laudit -L. -lutil"],
                  'DEFINE'	 => "$d_flag",
                  'INC'          => "-I$AFSPath/include",
                 );
}
else {
    print "AFS system type $alpha_sys not tested with this Makefile.PL ... \n\n";
    print "Maybe the default case will work. In order to test it,\n";
    print "just uncomment the code under this error message and run this step again.\n\n";
    print "If it is working, please inform the maintainer of this package. Thank you.\n\n";
    die "task aborted ... \n";
#    WriteMakefile(
#                  'NAME'         => 'AFS',
#                  'VERSION_FROM' => 'AFS.pm',
#                  'XS_VERSION'   => "$XS_VERSION",
#                  'LIBS'	  => ['-L$AFSPath/lib -L$AFSPath/lib/afs -lrx -lkauth -lprot -lubik -lauth -lrxkad -lsys -ldes -lrx -llwp -lcom_err -lutil -laudit /usr/lib/libresolv.a'],
#                  'DEFINE'	  => "$d_flag",
#                  'INC'          => '-I$AFSPath/include',
#                  );
}

# change the library name of the AFS system library "util.a"
my $command = "\'s#-lutil#$AFSPath/lib/afs/util.a#\'";
system ("perl -p -i.bak -e $command Makefile") unless -f "$AFSPath/lib/afs/libutil.a";
