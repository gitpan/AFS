# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More tests => 7;

BEGIN {
    use_ok('AFS::VLDB');
}

my $vldb = AFS::VLDB->new;
is(ref($vldb), 'AFS::VLDB', 'vldb->new()');

my $vldblist = $vldb->listvldbentry('root.afs');
isa_ok($vldblist, 'HASH', 'vldb->listvldbentry 1.level');
isa_ok($vldblist->{'root.afs'}, 'HASH', 'vldb->listvldbentry 2.level');
my $server = $vldblist->{'root.afs'}->{'server'}->[0]->{'name'};
my $part   = $vldblist->{'root.afs'}->{'server'}->[0]->{'partition'};

$vldblist = $vldb->listvldb($server, $part, 0);
isa_ok($vldblist, 'HASH', 'vldb->listvldb 1.level');

my @addrlist = $vldb->listaddrs($server);
is($addrlist[0]->{name}, $server, 'vldb->listaddrs(HOST)');

$vldb->DESTROY;
ok(! defined $vldb, 'vldb->DESTROY');

