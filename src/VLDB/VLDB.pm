package AFS::VLDB;
#------------------------------------------------------------------------------
# RCS-Id: "@(#)$Id: VLDB.pm 625 2004-05-05 13:30:16Z nog $"
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
$VERSION = do{my@r=q/Major Version 2.2 $Rev: 625 $/=~/\d+/g;$r[1]-=0;sprintf'%d.'.'%d'.'.%02d'x($#r-1),@r;};

sub DESTROY {
    my (undef, undef, undef, $subroutine) = caller(1);
    if (! defined $subroutine or $subroutine !~ /eval/) { undef $_[0]; }  # self->DESTROY
    else { AFS::VLDB::_DESTROY($_[0]); }                                  # undef self
}

sub delentry {
    my $self   = shift;
    my $volume = shift;
    my $noexec = shift;

    $noexec = 0 unless $noexec;

    if (ref($volume) eq 'SCALAR' or ref($volume) eq '' ) {
        my @volumes;
        $volumes[0] = $volume;
        $self->_delentry(\@volumes, '', '', '', $noexec);
    }
    else {
        $self->_delentry($volume, '', '', '', $noexec);
    }
}

sub delgroups {
    my $self   = shift;
    my $prefix = shift;
    my $server = shift;
    my $part   = shift;
    my $noexec = shift;

    $noexec = 0 unless $noexec;
    $self->_delentry('', $prefix, $server, $part, $noexec);
}

sub listvldb {
    my $self = shift;

    $self->_listvldb('', @_);
}

sub listvldbentry {
    my $self = shift;

    $self->_listvldb($_[0]);
}


sub removeaddr {
    my $self    = shift;
    my $ip_addr = shift;

    $self->_changeaddr($ip_addr, 0, 1);
}
sub syncvldb {
    my $self = shift;

    $self->_syncvldb(@_);
}

sub syncvldbentry {
    my $self = shift;

    $self->_syncvldb('', '', $_[0]);
}

1;
