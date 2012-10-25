package AFS::KTC_EKEY;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KTC_EKEY.pm 1059 2011-11-18 12:32:20Z nog $"
#
# © 2001-2010 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = 'v2.6.3';

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
