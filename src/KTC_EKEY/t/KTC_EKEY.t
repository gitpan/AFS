# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More tests => 3;

BEGIN {
    use_ok('AFS::KTC_EKEY');
}

my $dkey = AFS::KTC_EKEY->des_string_to_key('abc');
is(ref($dkey), 'AFS::KTC_EKEY', 'des_string_to_key(abc)');

use AFS::Cell qw(localcell);
my $skey = AFS::KTC_EKEY->StringToKey('abc', localcell);
is(ref($skey), 'AFS::KTC_EKEY', 'StringToKey(abc,localcell)');
