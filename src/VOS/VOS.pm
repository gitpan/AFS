package AFS::VOS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: VOS.pm 564 2004-02-02 08:15:47Z nog $"
#
# Copyright © 2003-2004 Alf Wachsmann <alfw@slac.stanford.edu> and
#                       Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 564 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

sub DESTROY {
    my (undef, undef, undef, $subroutine) = caller(1);
    if (! $subroutine) { undef $_[0]; }    # self->DESTROY
    else { AFS::VOS::_DESTROY($_[0]); }    # undef self
}

sub setquota {
    my $self   = shift;
    my $volume = shift;
    my $quota  = shift;

    $self->_setfields($volume, $quota);
}

sub backupsys {
    my $self = shift;

    if (ref($_[0]) eq 'SCALAR' or ref($_[0]) eq '' ) {
        my (@prefix, @xprefix);
        my @args = @_;
        $prefix[0] = $args[0];
        $args[0] = \@prefix;
        if ($args[4]) {
            $xprefix[0] = $args[4];
            $args[4] = \@xprefix;
        }
       $self->_backupsys(@args);
    }
    else {
       $self->_backupsys(@_);
    }
}

1;
