package AFS::KTC_EKEY;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KTC_EKEY.pm 528 2004-01-06 18:36:03Z nog $"
#
# Copyright � 2001-2004 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 528 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

sub UserReadPassword {
    my $class = shift;

    AFS::ka_UserReadPassword(@_);
}

sub ReadPassword {
    my $class  = shift;

    AFS::ka_ReadPassword(@_);
}

sub StringToKey {
    my $class   = shift;

    AFS::ka_StringToKey(@_);
}

sub des_string_to_key {
    my $class   = shift;

    AFS::ka_des_string_to_key(@_);
}


# struct ktc_encryptionKey {
#     char data[8];
# };

1;
