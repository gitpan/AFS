# -*-cperl-*-

use strict;
use lib qw(../../inc ../inc);

use Test::More;

BEGIN {
    use AFS::FS;
    if (AFS::FS::isafs('./')) { plan tests => 13; }
    else { plan skip_all => 'Working directory is not in AFS file system ...'; }

    use_ok('AFS::ACL');
}

is(AFS::ACL->ascii2rights('write'), 63, 'ascii2rights');

my $acl = AFS::ACL->new({'foobar' => 'none'}, {'anyuser' => 'write'});
is(ref($acl), 'AFS::ACL', 'AFS::ACL->new()');

$acl->set('rjs' => 'write');
is("$acl->[0]->{rjs}", 'write', 'set');
$acl->nset('opusl' => 'write');
is("$acl->[1]->{opusl}", 'write', 'nset');

$acl->remove('rjs' => 'write');
ok(! defined $acl->[0]->{rjs}, 'remove');

$acl->clear;
ok(! defined $acl->[0]->{foobar}, 'clear');

can_ok('AFS::ACL', qw(apply));

can_ok('AFS::ACL', qw(modifyacl));

can_ok('AFS::ACL', qw(cleanacl));

my $copy = $acl->copy;
is(ref($copy), 'AFS::ACL', 'acl->copy()');

my $rights = AFS::ACL->crights('read');
is($rights, 'rl', 'crights');

my $new_acl = AFS::ACL->retrieve('./');
is(ref($new_acl), 'AFS::ACL', 'AFS::ACL->retrieve()');
