package AFS::KTC_TOKEN;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KTC_TOKEN.pm 528 2004-01-06 18:36:03Z nog $"
#
# Copyright © 2001-2004 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 528 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

sub nulltoken {
    my $class  = shift;

    AFS::ka_nulltoken;
}

sub GetAdminToken {
    my $class  = shift;

    AFS::ka_GetAdminToken(@_);
}

sub GetAuthToken {
    my $class  = shift;

    AFS::ka_GetAuthToken(@_);
}

sub GetServerToken {
    my $class  = shift;

    AFS::ka_GetServerToken(@_);
}

sub GetToken {
    my $class  = shift;

    AFS::ktc_GetToken(@_);
}

sub FromString {
    my $class  = shift;

    AFS::ktc_FromString(@_);
}

sub SetToken {
    my $class  = shift;

    AFS::ktc_SetToken(@_);
}

sub UserAuthenticateGeneral {
    my $class = shift;

    AFS::ka_UserAthenticateGeneral(@_);
}

sub ForgetAllTokens {
    my $class = shift;

    AFS::ktc_ForgetAllTokens;
}


# struct ktc_token {
#     afs_int32 startTime;
#     afs_int32 endTime;
#     struct ktc_encryptionKey sessionKey;
#     short kvno;  /* XXX UNALIGNED */
#     int ticketLen;
#     char ticket[MAXKTCTICKETLEN];
# };

1;
