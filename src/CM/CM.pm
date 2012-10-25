package AFS::CM;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: CM.pm 1059 2011-11-18 12:32:20Z nog $"
#
# © 2001-2010 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
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
$VERSION = 'v2.6.3';

1;
