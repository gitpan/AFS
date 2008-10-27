package AFS::VOS;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: VOS.pm 853 2008-10-11 08:55:12Z nog $"
#
# Copyright © 2005-2008 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#           © 2003-2004 Alf Wachsmann <alfw@slac.stanford.edu> and
#                       Norbert E. Gruener <nog@MPA-Garching.MPG.de>
#
# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#------------------------------------------------------------------------------

use Carp;
use AFS ();

use vars qw(@ISA $VERSION);

@ISA     = qw(AFS);
$VERSION = '2.6.0';

sub DESTROY {
    my (undef, undef, undef, $subroutine) = caller(1);
    if (! defined $subroutine or $subroutine !~ /eval/) { undef $_[0]; }  # self->DESTROY
    else { AFS::VOS::_DESTROY($_[0]); }                                   # undef self
}

sub setquota {
    my $self   = shift;
    my $volume = shift;
    my $quota  = shift;

    $self->_setfields($volume, $quota);
}

sub backupsys {
    my $self = shift;

    if ($#_ > -1 and ! defined $_[0]) { $_[0] = ''; }

    if (ref($_[0]) eq 'ARRAY') {
        $self->_backupsys(@_);
    }
    elsif (ref($_[0]) eq '') {
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
        carp "AFS::VOS->backupsys: not a valid input ...\n";
        return (undef, undef);
    }
}

1;
