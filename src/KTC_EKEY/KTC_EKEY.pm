package AFS::KTC_EKEY;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KTC_EKEY.pm 919 2009-10-16 10:34:03Z nog $"
#
# Copyright © 2001-2009 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = 'v2.6.2';

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
