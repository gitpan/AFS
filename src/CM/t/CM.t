# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More tests => 9;

BEGIN {
    use_ok('AFS::CM', qw (
                          checkvolumes
                          cm_access flush flushcb flushvolume
                          getcacheparms getcrypt
                         )
          );
}

can_ok('AFS::CM', qw(checkvolumes));

my $ok = cm_access('/afs');
ok($ok, 'cm_access(/afs)');

$ok = cm_access('/tmp');
ok(!$ok, 'cm_access(/tmp)');

can_ok('AFS::CM', qw(flush));

can_ok('AFS::CM', qw(flushcb));

can_ok('AFS::CM', qw(flushvolume));

my ($max, undef) = getcacheparms;
ok($max, 'getcacheparms');

can_ok('AFS::CM', qw(getcrypt));
