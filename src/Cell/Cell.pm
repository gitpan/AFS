package AFS::Cell;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: Cell.pm 662 2005-02-12 17:14:10Z nog $"
#
# Copyright © 2001-2005 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS;

use vars qw(@ISA $VERSION @EXPORT_OK);

require Exporter;

@EXPORT_OK = qw(
                configdir
                expandcell
                getcellinfo
                localcell
                whichcell
                wscell
               );
@ISA     = qw(Exporter AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 662 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

1;
