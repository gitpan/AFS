# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More tests => 4;

BEGIN {
    use_ok('AFS::KAS');
}

use AFS::KTC_TOKEN;
my $kas = AFS::KAS->AuthServerConn(AFS::KTC_TOKEN->nulltoken, &AFS::KA_MAINTENANCE_SERVICE);
is(ref($kas), 'AFS::KAS', 'KAS->AuthServerConn(nulltoken)');

my $rkey = $kas->randomkey;
is(ref($rkey), 'AFS::KTC_EKEY', 'kas->randomkey');

$kas->DESTROY;
ok(! defined $kas, 'kas->DESTROY');
