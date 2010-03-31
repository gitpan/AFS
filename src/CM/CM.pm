package AFS::CM;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: CM.pm 919 2009-10-16 10:34:03Z nog $"
#
# Copyright © 2001-2009 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
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
$VERSION = 'v2.6.2';

1;
