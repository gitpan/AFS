# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 7; }
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
like($status, qr/No active transactions/, 'vos->status(server)');

$vos->DESTROY;
ok(! defined $vos, 'vos->DESTROY');
