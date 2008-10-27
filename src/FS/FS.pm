package AFS::FS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: FS.pm 853 2008-10-11 08:55:12Z nog $"
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
                getquota
                isafs
                lsmount
                mkmount
                rmmount
                setquota
                whereis
               );
@ISA     = qw(Exporter AFS);
$VERSION = '2.6.0';

1;
