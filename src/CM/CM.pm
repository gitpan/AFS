package AFS::CM;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: CM.pm 528 2004-01-06 18:36:03Z nog $"
#
# Copyright © 2001-2004 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS;

use vars qw(@ISA $VERSION @EXPORT_OK);

require Exporter;

@EXPORT_OK = qw(
                checkconn
                checkservers
                checkvolumes
                cm_access
                flush
                flushcb
                flushvolume
                getcacheparms
                getcellstatus
                getcrypt
                getvolstats
                setcachesize
                setcellstatus
                setcrypt
               );
@ISA     = qw(Exporter AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 528 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

1;
