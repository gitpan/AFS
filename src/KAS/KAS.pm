package AFS::KAS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: KAS.pm 824 2008-10-03 14:39:04Z nog $"
#
# Copyright © 2001-2008 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = '2.4.1';

# not suported anymore
# please use the functions from AFS::Cell !!!
#
# sub LocalCell {
#     my $class  = shift;

#     AFS::localcell;
# }

# sub ExpandCell {
#     my $class  = shift;

#     AFS::expandcell(@_);
# }

# sub CellToRealm {
#     my $class  = shift;

#     uc(AFS::expandcell(@_));
# }

sub DESTROY {
    my (undef, undef, undef, $subroutine) = caller(1);
    if (! defined $subroutine or $subroutine !~ /eval/) { undef $_[0]; }  # self->DESTROY
    else { AFS::KAS::_DESTROY($_[0]); }                                   # undef self
}

sub AuthServerConn {
    my $class = shift;

    AFS::ka_AuthServerConn(@_);
}

sub SingleServerConn {
    my $class = shift;

    AFS::ka_SingleServerConn(@_)
}

sub ChangePassword {
    my $self = shift;

    $self->ka_ChangePassword(@_)
}

sub Authenticate {
    my $self = shift;

    $self->ka_Authenticate(@_);
}

sub GetToken {
    my $self = shift;

    $self->ka_GetToken(@_)
}

# *** CAUTION ***
# these functions are redundant, they are also stored in AFS.pm  !!!

sub getentry    { $_[0]->KAM_GetEntry($_[1],$_[2]); }
sub debug       { $_[0]->KAM_Debug(&AFS::KAMAJORVERSION); }
sub getstats    { $_[0]->KAM_GetStats(&AFS::KAMAJORVERSION); }
sub randomkey   { $_[0]->KAM_GetRandomKey; }
sub create      { $_[0]->KAM_CreateUser($_[1],$_[2],$_[3]); }
sub setpassword { $_[0]->KAM_SetPassword($_[1],$_[2],$_[3],$_[4]); }
sub delete      { $_[0]->KAM_DeleteUser($_[1],$_[2]); }
sub listentry   { $_[0]->KAM_ListEntry($_[1],$_[2],$_[3]); }
sub setfields   { $_[0]->KAM_SetFields($_[1],$_[2],$_[3],$_[4],$_[5],$_[6],$_[7]); }

1;
