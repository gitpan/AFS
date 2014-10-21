package AFS::PTS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: PTS.pm 824 2008-10-03 14:39:04Z nog $"
#
# Copyright � 2001-2008 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = '2.4.1';

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

sub DESTROY {
    my (undef, undef, undef, $subroutine) = caller(1);
    if (! defined $subroutine or $subroutine !~ /eval/) { undef $_[0]; }  # self->DESTROY
    else { AFS::PTS::_DESTROY($_[0]); }                                   # undef self
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
