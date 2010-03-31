# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);
use blib;

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 52; }
    else { plan skip_all => 'Working directory is not in AFS file system ...'; }

    use_ok('AFS::VLDB');
}

my $vldb = AFS::VLDB->new;
is(ref($vldb), 'AFS::VLDB', 'vldb->new()');

my $vldblist = $vldb->listvldbentry('nonexisting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->listvldbentry(nonext_vol)');

$vldblist = $vldb->listvldbentry('root.afs');
isa_ok($vldblist, 'HASH', 'vldb->listvldbentry 1.level');
isa_ok($vldblist->{'root.afs'}, 'HASH', 'vldb->listvldbentry 2.level');

my $server = $vldblist->{'root.afs'}->{'server'}->[0]->{'name'};
my $part   = $vldblist->{'root.afs'}->{'server'}->[0]->{'partition'};
$vldblist = $vldb->listvldb($server, $part, 0);
isa_ok($vldblist, 'HASH', 'vldb->listvldb 1.level');

$vldblist = $vldb->listvldb('nonexiting_server', '/vicepa', 0);
like($AFS::CODE, qr/not found in host table/, 'vldb->listvldb(nonext_serv)');

$vldblist = $vldb->listvldb($server, 'nonexiting_partition', 0);
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->listvldb(nonext_part)');

my @addrlist = $vldb->listaddrs('nonexisting_server');
like($AFS::CODE, qr/Can't get host info/, 'vldb->listaddrs(nonext_serv)');

@addrlist = $vldb->listaddrs($server);
is($addrlist[0]->{'name-1'}, $server, 'vldb->listaddrs(HOST)');

@addrlist = $vldb->listaddrs;
ok(defined $addrlist[0], 'vldb->listaddrs()');

my $ok = $vldb->lock('nonexisting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->lock');
ok(! $ok, 'vldb->lock');

$vldb->unlockvldb('nonexiting_server', '/vicepa');
like($AFS::CODE, qr/not found in host table/, 'vldb->unlockvldb(nonext_serv)');

$vldb->unlockvldb($server, 'nonexiting_partition');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->unlockvldb(nonext_part)');

$ok = $vldb->unlock('nonexisting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->unlock');
ok(! $ok, 'vldb->unlock');

$vldb->addsite('nonexiting_server', '/vicepa', 'root.afs');
like($AFS::CODE, qr/not found in host table/, 'vldb->addsite(nonext_serv)');

$vldb->addsite($server, 'nonexiting_partition', 'root.afs');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->addsite(nonext_part)');

$vldb->addsite($server, $part, 'nonexiting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->addsite(nonext_vol)');

$vldb->changeloc('root.afs', 'nonexiting_server', '/vicepa');
like($AFS::CODE, qr/not found in host table/, 'vldb->changeloc(nonext_serv)');

$vldb->changeloc('root.afs', $server, 'nonexiting_partition');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->changeloc(nonext_part)');

$vldb->changeloc('nonexiting_volume', $server, $part);
like($AFS::CODE, qr/no such entry/, 'vldb->changeloc(nonext_vol)');

my ($succ, $fail) = $vldb->delentry('nonexiting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->delentry(nonext_vol)');
ok(! $succ, 'succ = vldb->delentry(nonext_vol)');
ok(! $fail, 'fail = vldb->delentry(nonext_vol)');

($succ, $fail) = $vldb->delgroups('', '', '', '');
like($AFS::CODE, qr/You must specify an argument/, 'vldb->delgroups(no arguments)');
ok(! $succ, 'succ = vldb->delgroups(no arguments)');
ok(! $fail, 'fail = vldb->delgroups(no arguments)');

($succ, $fail) = $vldb->delgroups('prefix', '', '', '');
like($AFS::CODE, qr/must provide SERVER with the PREFIX/, 'vldb->delgroups(no server-1)');
ok(! $succ, 'succ = vldb->delgroups(no server-1)');
ok(! $fail, 'fail = vldb->delgroups(no server-1)');

($succ, $fail) = $vldb->delgroups('prefix', 'nonexiting_server', '', '');
like($AFS::CODE, qr/ not found in host table/, 'vldb->delgroups(nonexiting_server)');
ok(! $succ, 'succ = vldb->delgroups(nonexiting_server)');
ok(! $fail, 'fail = vldb->delgroups(nonexiting_server)');

($succ, $fail) = $vldb->delgroups('prefix', '', 'partition', '');
like($AFS::CODE, qr/must provide SERVER with the PARTITION/, 'vldb->delgroups(no server-2)');
ok(! $succ, 'succ = vldb->delgroups(no server-2)');
ok(! $fail, 'fail = vldb->delgroups(no server-2)');

($succ, $fail) = $vldb->delgroups('prefix', $server, 'nonexisting_partition', '');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->delgroups(nonext_part)');
ok(! $succ, 'succ = vldb->delgroups(nonext_part)');
ok(! $fail, 'fail = vldb->delgroups(nonext_part)');

$vldb->remsite('nonexiting_server', '/vicepa', 'root.afs');
like($AFS::CODE, qr/not found in host table/, 'vldb->remsite(nonext_serv)');

$vldb->remsite($server, 'nonexiting_partition', 'root.afs');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->remsite(nonext_part)');

$vldb->remsite($server, $part, 'nonexiting_volume');
like($AFS::CODE, qr/no such entry/, 'vldb->remsite(nonext_vol)');

$vldb->syncserv('nonexiting_server', '/vicepa');
like($AFS::CODE, qr/not found in host table/, 'vldb->syncserv(nonext_serv)');

$vldb->syncserv($server, 'nonexiting_partition');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->syncserv(nonext_part)');

$vldb->syncvldb('nonexiting_server', '/vicepa');
like($AFS::CODE, qr/not found in host table/, 'vldb->syncvldb(nonext_serv)');

$vldb->syncvldb($server, 'nonexiting_partition');
like($AFS::CODE, qr/could not interpret partition name/, 'vldb->syncvldb(nonext_part)');

$ok = $vldb->syncvldbentry('nonexiting_volume');
ok($ok, 'vldb->syncvldbentry(nonext_vol)');

$vldb->removeaddr('');
like($AFS::CODE, qr/invalid host address/, 'vldb->removeaddr(no arguments)');

$vldb->removeaddr('127.0.0.1');
like($AFS::CODE, qr/no such entry/, 'vldb->removeaddr(invalid IP)');

$vldb->DESTROY;
ok(! defined $vldb, 'vldb->DESTROY');
