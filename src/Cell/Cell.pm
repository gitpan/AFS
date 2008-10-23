package AFS::Cell;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: Cell.pm 824 2008-10-03 14:39:04Z nog $"
#
# Copyright © 2001-2008 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
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
$VERSION = '2.4.1';

1;
