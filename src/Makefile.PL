#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: Makefile.PL 621 2004-05-05 10:01:34Z nog $"
#
# Copyright © 2001-2004 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------
use strict;
use English;

use ExtUtils::MakeMaker;
use Config;

my $archname = $Config{'archname'};
if ($archname =~ /thread/i) { die "Threaded Perl is not supported ...\n"; }

my $VERSION;
my $head_url = '$HeadURL: svn+ssh://Fuji/afs/mpa/home/nog/SVN-Repositories/afsperl/tags/release-2.2.2/src/Makefile.PL $';
if ($head_url =~ /rc\d/) {
    # release candidate
    $VERSION = do{my@r=q\$HeadURL: svn+ssh://Fuji/afs/mpa/home/nog/SVN-Repositories/afsperl/tags/release-2.2.2/src/Makefile.PL $\=~/\d+/g;sprintf'%d.%d.%d-rc%d',$r[0],$r[1],$r[2],$r[3];};
}
elsif ($head_url =~ /release/) {
    # normal release
    $VERSION = do{my($a,$b)=split(/SVN/,q\$HeadURL: svn+ssh://Fuji/afs/mpa/home/nog/SVN-Repositories/afsperl/tags/release-2.2.2/src/Makefile.PL $\);my@r=$b=~/\d+/g;sprintf'%d.'.'%d'.'.%d'x($#r-1),@r;};
}
else {
    # development release
    $VERSION = do{my@r=q/Major Version 2.2 $Rev: 621 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%d'x($#r-1),@r;};
}

# give me the path to the AFS system libraries
# used to build the AFS extension module
my $guess_path;
if    (-r "/usr/local/include/afs/afs.h") { $guess_path = '/usr/local'; }
elsif (-r "/usr/afsws/include/afs/afs.h") { $guess_path = '/usr/afsws'; }
elsif (-r "/usr/include/afs/afs.h")       { $guess_path = '/usr'; }

my $AFSPath;
if (defined $ENV{AFSPATH}) {
    $AFSPath = $ENV{AFSPATH};
}
else {
    $AFSPath = $guess_path || 'unknown';
    print "\nPath to the AFS installation (libraries, binaries, \n";
    print "header files) to be used for this installation? \t [$AFSPath] ";
    chomp(my $answer = <STDIN>);
    $AFSPath = $answer if $answer;
    print "\n";
}

$AFSPath =~ s\/$\\;

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

system("$Config::Config{cc} fotav.c -L$AFSPath/lib -lubik");
if ($CHILD_ERROR) {
    unlink 'fotav.c';
    die "\nCould not compile test code to retrieve the version of AFS system libraries...\n";
}
my $version = `./a.out` || die "\nCould not run test code to retrieve the version of AFS system libraries...\n";
unlink 'a.out', 'fotav.c';
print "AFS Version = $version \n";

if ($version =~ /3.[4,5]/)   { warn "This release does not support AFS 3.4/3.5 system libraries ...\n"; exit 1; }

# set the compiler flag "-D$version" according to the AFS version
my ($d_flag, $a_flag) = ('', '');
if    ($version =~ /3.4/)   { $d_flag = 'AFS 3.4'; }
elsif ($version =~ /3.5/)   { $d_flag = 'AFS 3.5'; }
elsif ($version =~ /3.6/)   { $d_flag = 'AFS 3.6'; }
elsif ($version =~ /1.0/)   { $d_flag = 'OpenAFS 1.0'; }
elsif ($version =~ /1.1/)   { $d_flag = 'OpenAFS 1.1'; }
elsif ($version =~ /1.2/)   { $d_flag = 'OpenAFS 1.2'; }
elsif ($version =~ /devel/) { $d_flag = 'OpenAFS devel'; }

if ($version =~ /openafs/)  { $a_flag = '-DOpenAFS'; }

$version = $d_flag;
$d_flag =~ tr/\. /__/;
$d_flag = '-D' . $d_flag;

# determine the alpha_sys value
#my $alpha_sys = 'i386_linux24';
my $alpha_sys = `$AFSPath/bin/fs sysname 2>&1` || 'unknown';
if ($alpha_sys =~ s/Current sysname is:? //) {
    $alpha_sys =~ s/list? //;
    $alpha_sys =~ /(\w+)/;
    $alpha_sys = $1;
}

# print out a summary of determined data
print "Your AFS system library is located at:  $AFSPath \n";
print "              and it is major version:  $version \n";
print "Your AFS system type seems to be:       $alpha_sys \n\n";

# set the Makefile values
my %MakefileArgs = (
    'NAME'         => 'AFS',
    'VERSION'      => "$VERSION",
    'DEFINE'	   => "$d_flag $a_flag",
    'INC'          => "-I$AFSPath/include",
    'LIBS'         => [
                       "-L$AFSPath/lib -L$AFSPath/lib/afs "
                       . join (
                                   " ", qw(
                                           -lkauth
                                           -lprot
					   -lbos
                                           -lrx
                                           -lvolser
                                           -lvldb

                                           -lcmd
                                           -lubik
                                           -lauth

                                           -lrxkad
                                           -lrxstat
                                           -lrx

                                           -lsys
                                           -ldes
                                           -llwp
                                           -lcom_err
                                           -lutil
                                           -lusd
                                           -laudit
                                          )
                              )
                      ],
    'realclean'    => {FILES => 'Makefile.bak lib'},
                   );

if ($Config{osname} =~ /aix/) {
    $MakefileArgs{LIBS}->[0] .= ' -ldl';
}
elsif ($Config{osname} =~ /irix/) {
   # just the default LIBS
}
elsif ($Config{osname} =~ /solaris/) {
    $MakefileArgs{DEFINE} .= ' -Dint32=afs_int32 -Duint32=afs_uint32' if $alpha_sys eq 'sun4x_56'; # From Peter@PSDT.com
    $MakefileArgs{LIBS}->[0] .= ' -lresolv -lsocket -lnsl -lintl -ldl';
    $MakefileArgs{CC} = 'gcc';
    #$MakefileArgs{LD} = 'gcc';
    $MakefileArgs{CCCDLFLAGS} = '-fPIC';
}
elsif ($Config{osname} =~ /linux/) {
    $MakefileArgs{LIBS}->[0] .= ' -lresolv';
}
# elsif ($Config{osname} =~ /dec_osf/) {
# # hier fehlt noch was !!!!!
# }
else {
    warn("System type '$Config{osname}' not yet tested with this Makefile.PL...\n\n"
         . "Using the default values, which may or may not work\n"
         . "If it is working, please inform the maintainer of this package.\n"
         . "Thank you.\n\n");
}

WriteMakefile(%MakefileArgs);

# change the library name of the AFS system library "util.a"
my $command = "\'s#-lutil#$AFSPath/lib/afs/util.a#\'";
system("perl -p -i.bak -e $command Makefile") unless -f "$AFSPath/lib/afs/libutil.a";

# change the library name of the AFS system library "vlib.a"
my $command = "\'s#-lvlib#$AFSPath/lib/afs/vlib.a#\'";
system("perl -p -i.bak -e $command Makefile") unless -f "$AFSPath/lib/afs/libvlib.a";

# change the library name of the AFS system library "libcom_err"
$command = "\'s#-lcom_err#$AFSPath/lib/afs/libcom_err.a#\'";
system("perl -p -i.bak -e $command Makefile");

# make changes to the typemap file if Perl < 5.6.0
$command = "\'s#T_UV#T_IV#\'";
system("perl -p -i.bak -e $command typemap") unless $] >= 5.006;
