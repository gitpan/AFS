# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More tests => 9;

my ($quota, @hosts);

BEGIN {
    use_ok(
           'AFS::FS', qw(
                         getquota setquota whereis
                         isafs lsmount mkmount rmmount
                        )
          );
}

use AFS::Cell qw(localcell);
my $cell = localcell;

$quota = getquota("/afs/$cell");
ok(defined $quota, 'getquota');

can_ok('AFS::FS', qw(setquota));

ok(isafs("/afs/$cell") eq 1, 'isafs (file in AFS)');
ok(isafs('/tmp') eq 0, 'isafs (file not in AFS)');

@hosts = whereis("/afs/$cell");
ok($#hosts ge 0, 'whereis');

can_ok('AFS::FS', 'mkmount');

can_ok('AFS::FS', 'rmmount');

can_ok('AFS::FS', 'lsmount');
