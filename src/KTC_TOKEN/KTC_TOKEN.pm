package AFS::KTC_TOKEN;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)KTC_TOKEN.pm,v 2.0 2002/07/02 06:13:26 nog Exp"
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
