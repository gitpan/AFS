package AFS::KTC_PRINCIPAL;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)KTC_PRINCIPAL.pm,v 2.0 2002/07/02 06:13:13 nog Exp"
#
# Copyright © 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS;

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = sprintf("%d.%02d", q/2.0/ =~ /(\d+)\.(\d+)/);

sub ListTokens {
    my $class  = shift;

    AFS::ktc_ListTokens(@_);
}

sub ParseLoginName {
    my $class = shift;

    AFS::ka_ParseLoginName(@_);
}

{ # this is to please version 1 and to avoid warning about redefined subroutines
no warnings;

sub new {
    # this whole construct is to please the old version from Roland
    if ($_[0] =~ /AFS::KTC_PRINCIPAL/) { my $class  = shift; }
    my $name  = shift;
    my $inst  = shift;
    my $cell  = shift;

    my @args = ();
    push @args, $name if defined $name;
    push @args, $inst if defined $inst;
    push @args, $cell if defined $cell;
    AFS::KTC_PRINCIPAL::_new('AFS::KTC_PRINCIPAL', @args);
}

}


# struct ktc_principal {
#     char name[MAXKTCNAMELEN];
#     char instance[MAXKTCNAMELEN];
#     char cell[MAXKTCREALMLEN];
# };

1;
