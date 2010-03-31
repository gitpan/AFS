# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);
use blib;

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 28; }
    else { plan skip_all => 'Working directory is not in AFS file system ...'; }

    use_ok('AFS::VOS');
}

my $vos = AFS::VOS->new;
is(ref($vos), 'AFS::VOS', 'vos->new()');

use AFS::VLDB;
my $vldb = AFS::VLDB->new;
my $vldblist = $vldb->listvldbentry('root.afs');
my $server = $vldblist->{'root.afs'}->{'server'}->[0]->{'name'};
my $part   = $vldblist->{'root.afs'}->{'server'}->[0]->{'partition'};

my $vollist = $vos->listvol($server, $part, 1, 1);
like($AFS::CODE, qr/FAST and EXTENDED flags are mutually exclusive/, 'vos->listvol(fast, extended)');

$vollist = $vos->listvol($server, 'nonextist_part');
like($AFS::CODE, qr/could not interpret partition name/, 'vos->listvol(nonext_part)');

$vollist = $vos->listvol($server, $part);
isa_ok($vollist->{$part}->{'root.afs'}, 'HASH', 'vos->listvol(server partition)');

$vos->listpart('nonextist_server');
like($AFS::CODE, qr/not found in host table/, 'vos->listpart(nonext_server)');

my @partlist = $vos->listpart($server);
ok($#partlist > -1, 'vos->listpart(server)');

$vos->partinfo('nonextist_server');
like($AFS::CODE, qr/not found in host table/, 'vos->partinfo(nonext_server)');

$vos->partinfo($server, 'nonextist_part');
like($AFS::CODE, qr/could not interpret partition name/, 'vos->partinfo(nonext_part)');

isa_ok($vos->partinfo($server), 'HASH', 'vos->partinfo(server)');

$vos->status('nonexist_server');
like($AFS::CODE, qr/not found in host table/, 'vos->status(nonext_server)');

my $status = $vos->status($server);
like($status, qr/transactions/, 'vos->status(server)');

$vos->backupsys('prefix', 'nonexist_server');
like($AFS::CODE, qr/not found in host table/, 'vos->backupsys(nonext_server)');

$vos->backupsys('prefix', $server, 'nonextist_part');
like($AFS::CODE, qr/could not interpret partition name/, 'vos->backupsys(nonext_part)');

$vos->listvolume('nonextist_volume');
like($AFS::CODE, qr/no such entry/, 'vos->listvolume(nonext_volume)');

$vos->DESTROY;
ok(! defined $vos, 'vos->DESTROY');

can_ok('AFS::VOS', qw(backup));
can_ok('AFS::VOS', qw(create));
can_ok('AFS::VOS', qw(dump));
can_ok('AFS::VOS', qw(move));
can_ok('AFS::VOS', qw(offline));
can_ok('AFS::VOS', qw(online));
can_ok('AFS::VOS', qw(release));
can_ok('AFS::VOS', qw(remove));
can_ok('AFS::VOS', qw(rename));
can_ok('AFS::VOS', qw(restore));
can_ok('AFS::VOS', qw(setquota));
can_ok('AFS::VOS', qw(zap));
