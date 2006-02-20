# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 32; }
    else { plan skip_all => 'Working directory is not in AFS file system ...'; }

    use_ok('AFS::BOS');
}

use AFS::VLDB;
use AFS::Cell 'localcell';
my $vldb = AFS::VLDB->new;
my $vldblist = $vldb->listvldbentry('root.afs');
my $server = $vldblist->{'root.afs'}->{'server'}->[0]->{'name'};
my $l_cell = localcell;

my $bos = AFS::BOS->new($server);
is(ref($bos), 'AFS::BOS', 'bos->new()');

my ($cell, $hostlist) = $bos->listhosts;
is($cell, $l_cell, 'bos-listhost: Cellname OK');
ok($#$hostlist > 0, 'bos->listhost: Host list OK');

my @users = $bos->listusers;
ok($#users > 0, 'bos->listusers: User list OK');

my ($generalTime, $newBinaryTime) = $bos->getrestart;
ok(defined $generalTime, 'bos->getrestart: GeneralTime OK');
ok(defined $newBinaryTime, 'bos->getrestart: NewBinaryTime OK');

my $result = $bos->status(0, [ 'fs' ]);
isa_ok($result->{fs}, 'HASH', 'bos->status OK');

$bos->DESTROY;
ok(! defined $bos, 'bos->DESTROY');

can_ok('AFS::BOS', qw(addhost));
can_ok('AFS::BOS', qw(addkey));
can_ok('AFS::BOS', qw(adduser));
can_ok('AFS::BOS', qw(create));
can_ok('AFS::BOS', qw(delete));
can_ok('AFS::BOS', qw(exec));
can_ok('AFS::BOS', qw(getlog));
can_ok('AFS::BOS', qw(getrestricted));
can_ok('AFS::BOS', qw(listkeys));
can_ok('AFS::BOS', qw(prune));
can_ok('AFS::BOS', qw(removehost));
can_ok('AFS::BOS', qw(removekey));
can_ok('AFS::BOS', qw(removeuser));
can_ok('AFS::BOS', qw(restart_bos));
can_ok('AFS::BOS', qw(restart_all));
can_ok('AFS::BOS', qw(restart));
can_ok('AFS::BOS', qw(setauth));
can_ok('AFS::BOS', qw(setrestart));
can_ok('AFS::BOS', qw(setrestricted));
can_ok('AFS::BOS', qw(shutdown));
can_ok('AFS::BOS', qw(start));
can_ok('AFS::BOS', qw(startup));
can_ok('AFS::BOS', qw(stop));
