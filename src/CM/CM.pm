package AFS::CM;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)CM.pm,v 2.0 2002/07/02 06:12:02 nog Exp"
#
# Copyright © 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
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
                setcachesize
                setcellstatus
                setcrypt
               );
@ISA       = qw(Exporter AFS);
$VERSION   = sprintf("%d.%02d", q/2.0/ =~ /(\d+)\.(\d+)/);

1;
