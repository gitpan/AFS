# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);
use blib;

use Test::More tests => 10;


BEGIN {
    use_ok('AFS::KTC_TOKEN');
}

is(ref(AFS::KTC_TOKEN->nulltoken), 'AFS::KTC_TOKEN', 'AFS::KTC_TOKEN->nulltoken()');

can_ok('AFS::KTC_TOKEN', qw(GetAuthToken));
can_ok('AFS::KTC_TOKEN', qw(GetServerToken));
can_ok('AFS::KTC_TOKEN', qw(GetAdminToken));
can_ok('AFS::KTC_TOKEN', qw(GetToken));
can_ok('AFS::KTC_TOKEN', qw(SetToken));
can_ok('AFS::KTC_TOKEN', qw(UserAuthenticateGeneral));
can_ok('AFS::KTC_TOKEN', qw(ForgetAllTokens));
can_ok('AFS::KTC_TOKEN', qw(FromString));
