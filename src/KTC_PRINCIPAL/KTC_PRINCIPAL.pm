package AFS::KTC_PRINCIPAL;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KTC_PRINCIPAL.pm 662 2005-02-12 17:14:10Z nog $"
#
# Copyright © 2001-2005 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 662 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

sub ListTokens {
    my $class  = shift;

    AFS::ktc_ListTokens(@_);
}

sub ParseLoginName {
    my $class = shift;

    AFS::ka_ParseLoginName(@_);
}

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


# struct ktc_principal {
#     char name[MAXKTCNAMELEN];
#     char instance[MAXKTCNAMELEN];
#     char cell[MAXKTCREALMLEN];
# };

1;
