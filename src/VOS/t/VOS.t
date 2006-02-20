# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 21; }
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

my $vollist = $vos->listvol($server, $part);
isa_ok($vollist->{$part}->{'root.afs'}, 'HASH', 'vos->listvol(server partition)');

my @partlist = $vos->listpart($server);
ok($#partlist > -1, 'vos->listpart(server)');

isa_ok($vos->partinfo($server), 'HASH', 'vos->partinfo(server)');

my $status;
chomp($status = $vos->status($server));
like($status, qr/transactions/, 'vos->status(server)');

$vos->DESTROY;
ok(! defined $vos, 'vos->DESTROY');

can_ok('AFS::VOS', qw(backup));
can_ok('AFS::VOS', qw(backupsys));
can_ok('AFS::VOS', qw(create));
can_ok('AFS::VOS', qw(dump));
can_ok('AFS::VOS', qw(listvolume));
can_ok('AFS::VOS', qw(move));
can_ok('AFS::VOS', qw(offline));
can_ok('AFS::VOS', qw(online));
can_ok('AFS::VOS', qw(release));
can_ok('AFS::VOS', qw(remove));
can_ok('AFS::VOS', qw(rename));
can_ok('AFS::VOS', qw(restore));
can_ok('AFS::VOS', qw(setquota));
can_ok('AFS::VOS', qw(zap));
