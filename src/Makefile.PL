#------------------------------------------------------------------------------
# RCS-Id: "@(#)Makefile.PL,v 1.12 2002/10/11 11:09:03 nog Exp"
#
# Copyright © 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use ExtUtils::MakeMaker;
use Config;

# set XS version to sync the PM-Version and the XS-Version
$XS_VERSION = do{my@r=q/V_2_03/=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};

# give me the path to the AFS system libraries
# used to build the AFS extension module
my $AFSPath = $ENV{AFSPATH} || '/usr/afsws';
print "Which AFS system libraries should be used? [$AFSPath] ";
chomp(my $answer = <STDIN>);
$AFSPath = $answer if $answer;
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

system ("$Config::Config{cc} fotav.c -L$AFSPath/lib -lubik");
if ($CHILD_ERROR) { die "\nCould not compile test code to retrieve the version of AFS system libraries...\n"; }
my $version = `./a.out` || die "\nCould not run test code to retrieve the version of AFS system libraries...\n";
unlink 'a.out', 'fotav.c';
print "AFS Version = $version \n";

# set the compiler flag "-D$version" according to the AFS version
my $d_flag = '';
if ($version =~ /3.4/)      { $d_flag = 'AFS 3.4'; }
elsif ($version =~ /3.5/)   { $d_flag = 'AFS 3.5'; }
elsif ($version =~ /3.6/)   { $d_flag = 'AFS 3.6'; }
elsif ($version =~ /1.0/)   { $d_flag = 'OpenAFS 1.0'; }
elsif ($version =~ /1.1/)   { $d_flag = 'OpenAFS 1.1'; }
elsif ($version =~ /1.2/)   { $d_flag = 'OpenAFS 1.2'; }
elsif ($version =~ /devel/) { $d_flag = 'OpenAFS devel'; }

$version = $d_flag;
$d_flag =~ tr/\. /__/;
$d_flag = '-D'.$d_flag;

# determine the alpha_sys value
#my $alpha_sys = 'i386_linux24';
my $alpha_sys = `$AFSPath/bin/fs sysname 2>&1` || die "No alpha_sys ... \n";
if ($alpha_sys =~ s/Current sysname is:? //) {
    $alpha_sys =~ s/list? //;
    $alpha_sys =~ /(\w+)/;
    $alpha_sys = $1;
}
else {
    $alpha_sys = '';
}

# print out a summary of determined data
print "Your AFS system library is located at:  $AFSPath \n";
print "              and it is major version:  $version \n";
print "Your AFS system type seems to be:       $alpha_sys \n\n" if $alpha_sys;


# set the Makefile values
my %MakefileArgs =
  (
   'NAME'         	=> 'AFS',
   'VERSION_FROM' 	=> 'AFS.pm',
   'XS_VERSION'   	=> "$XS_VERSION",
   'DEFINE'	 	=> "$d_flag",
   'INC'          	=> "-I$AFSPath/include",
   'LIBS'	  	=> ["-L$AFSPath/lib -L$AFSPath/lib/afs " .
			    join(" ",qw(-lrx -lkauth -lprot -lubik
					-lauth -lrxkad -lsys -ldes
					-lrx -llwp -lcom_err -lutil
					-laudit /usr/lib/libresolv.a))],
  );

if ( $Config{osname} =~ /aix|irix/ ) {
    $MakefileArgs{LIBS} = ["-L$AFSPath/lib -L$AFSPath/lib/afs " .
			   join(" ",qw(-lkauth -lprot -lubik -lauth
				       -lrxkad -lsys -ldes -lrx
				       -llwp -lcom_err -lutil -laudit))];
}
elsif ( $Config{osname} =~ /solaris/ ) {
    $MakefileArgs{DEFINE} .= ' -Dint32=afs_int32 -Duint32=afs_uint32' if $alpha_sys eq 'sun4x_56';  # From Peter@PSDT.com
    $MakefileArgs{LIBS} = ["-L$AFSPath/lib -L$AFSPath/lib/afs " .
			   join(" ",qw(-lkauth -lprot -lubik -lauth
				       -lrxkad -lsys -ldes -lrx
				       -llwp -lcom_err -lutil
                                       -laudit -lresolv
                                       -L/usr/ucblib -lucb))];
    $MakefileArgs{CC} = 'gcc';
#    $MakefileArgs{LD} = 'gcc';
    $MakefileArgs{CCCDLFLAGS} = '-fPIC';
}
elsif ( $Config{osname} =~ /linux/ ) {
    $MakefileArgs{LIBS} = ["-L$AFSPath/lib -L$AFSPath/lib/afs " .
			   join(" ",qw(-lkauth -lrx -lprot -lubik
				       -lauth -lrxkad -lsys -ldes
				       -llwp -lcom_err -lutil -laudit
				       -lvolser -lvldb -lcmd -lrx -lresolv))];
}
elsif ( $Config{osname} =~ /dec_osf/ ) {
    # Not sure about this one -- if sysname is alpha_dux40, what is Config{osname}??
    $MakefileArgs{LIBS} = ["-L$AFSPath/lib -L$AFSPath/lib/afs " .
			   join(" ",qw(-lkauth -lprot -lubik -lauth
				       -lrxkad -lsys -ldes -lrx
				       -llwp -lcom_err -laudit -L. -lutil))];
}
else {
    warn("System type '$Config{osname}' not yet tested with this Makefile.PL...\n\n" .
	 "Using the default values, which may or may not work\n" .
         "If it is working, please inform the maintainer of this package. Thank you.\n\n");
}

WriteMakefile(%MakefileArgs);

# change the library name of the AFS system library "util.a"
my $command = "\'s#-lutil#$AFSPath/lib/afs/util.a#\'";
system ("perl -p -i.bak -e $command Makefile") unless -f "$AFSPath/lib/afs/libutil.a";

# change the library name of the AFS system library "libcom_err"
$command = "\'s#-lcom_err#$AFSPath/lib/afs/libcom_err.a#\'";
system ("perl -p -i.bak -e $command Makefile");
