package AFS::PTS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)PTS.pm,v 2.1 2002/07/04 06:00:35 nog Exp"
#
# Copyright © 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = sprintf("%d.%02d", q/2.1/ =~ /(\d+)\.(\d+)/);

sub new {
    # this whole construct is to please the old version from Roland
    if ($_[0] =~ /AFS::PTS/) { my $class  = shift; }
    my $sec  = shift;
    my $cell = shift;

    my @args = ();
    push @args, $sec  if defined $sec;
    push @args, $cell if defined $cell;
    AFS::PTS::_new('AFS::PTS', @args);
}

sub ascii2ptsaccess {
    my $class  = shift;

    AFS::ascii2ptsaccess(@_);
}

sub ptsaccess2ascii {
    my $class = shift;

    AFS::ptsaccess2ascii(@_);
}

sub convert_numeric_names {
    my $class = shift;

    AFS::convert_numeric_names(@_);
}

1;
