# EAFDSS - Electronic Fiscal Signature Devices Library
#          Ειδική Ασφαλής Φορολογική Διάταξη Σήμανσης (ΕΑΦΔΣΣ)
#
# Copyright (C) 2008 Hasiotis Nikos
#
# ID: $Id: Base.pm 162 2008-05-08 18:44:54Z hasiotis $

package EAFDSS::Base;

use 5.006001;
use strict;
use warnings;
use Carp;
use Data::Dumper;

use base qw ( Class::Base );

sub init {
	my($self, $config) = @_;

	if (! exists $config->{DIR}) {
		return $self->error("You need to provide the DIR to save the singatures!");
	} else {
		$self->{DIR} = $config->{DIR};
	}

	if (! exists $config->{SN}) {
		return $self->error("You need to provide the Serial Number of the device!");
	} else {
		$self->{SN} = $config->{SN};
	}

	return $self;
}

sub Sign {
        my($self)  = shift @_;
        my($fname) = shift @_;
        my($reply, $totalSigns, $dailySigns, $date, $time, $nextZ, $sign, $fullSign);

        $self->debug("Sign operation");
        my($deviceDir) = $self->_createSignDir();
	if (! $deviceDir) {
		return 1;
	}

        if (-e $fname) {
                $self->debug(  "  Signing file [%s]", $fname);
                open(FH, $fname);
                ($reply, $totalSigns, $dailySigns, $date, $time, $nextZ, $sign) = $self->GetSign(*FH);
                $fullSign = sprintf("%s %04d %08d %s%s %s",
                        $sign, $dailySigns, $totalSigns, $self->date6ToHost($date), substr($time, 0, 4), $self->{SN});
                close(FH);

                $self->_createFileA($fname, $deviceDir, $date, $dailySigns, $nextZ);
                $self->_createFileB($fullSign, $deviceDir, $date, $dailySigns, $nextZ);
        } else {
                $self->debug(  "  No such file [%s]", $fname);
                return -1;
        }

        return($reply, $fullSign);
}


sub _createSignDir {
	my($self) = shift @_;

	my($result) = $self->_Recover();
	if ($result) {
		return undef;
	}

	# Create The signs Dir
	if (! -d  $self->{DIR} ) {
		$self->debug("  Creating Base Dir [%s]", $self->{DIR});
		mkdir($self->{DIR});
	}

	my($deviceDir) = sprintf("%s/%s", $self->{DIR}, $self->{SN});
	if (! -d $deviceDir ) {
		$self->debug("  Creating Device Dir [%s]", $deviceDir);
		mkdir($deviceDir);
	}

	return $deviceDir;
}

sub _Recover {
	my($self) = shift @_;
	my($reply, $status1, $status2, $lastZ, $total, $daily, $signBlock, $remainDaily);

	($reply, $status1, $status2) = $self->PROTO_GetStatus();
	if ($reply != 0) { return $reply};

	my($busy, $fatal, $paper, $cmos, $printer, $user, $fiscal, $battery) = $self->devStatus($status1);
	if ($cmos != 1) { return };

	my($day, $signature, $recovery, $fiscalWarn, $dailyFull, $fiscalFull) = $self->appStatus($status1);

	$self->debug("   CMOS is set, going for recovery!");

	($reply, $status1, $status2, $lastZ, $total, $daily, $signBlock, $remainDaily) = $self->ReadSummary(0);
	if ($reply != 0) {
		$self->debug("   Aborting recovery because of ReadClosure reply [%d]", $reply);
		return $reply
	};

	my($regexA) = sprintf("%s\\d{6}%04d\\d{4}_a.txt", $self->{SN}, $lastZ + 1);
	my($deviceDir) = sprintf("%s/%s", $self->{DIR}, $self->{SN});

	opendir(DIR, $deviceDir) || die "can't opendir $deviceDir: $!";
	my(@afiles) = grep { /$regexA/ } readdir(DIR);
	closedir(DIR);

	foreach my $curA (@afiles) {
		$self->debug("          Checking [%s]", $curA);
		my($curFileA) = sprintf("%s/%s", $deviceDir, $curA);

		my($curFileB) = $curFileA;
		$curFileB =~ s/_a/_b/;

		my($curB)  = $curA; $curB =~ s/_a/_b/;
		my($curIndex) = substr($curA, 21, 4); $curIndex =~ s/^0*//;
		$self->debug("            Updating file B  [%s] -- Index [%d]", $curB, $curIndex);

		$self->debug("            Resigning file A [%s]", $curA);
		open(FH, $curFileA);

		my($reply, $totalSigns, $dailySigns, $date, $time, $nextZ, $sign) = $self->GetSign(*FH);
		my($fullSign) = sprintf("%s %04d %08d %s%s %s", $sign, $dailySigns, $totalSigns, $self->date6ToHost($date), substr($time, 0, 4), $self->{SN});
		close(FH);

		open(FB, ">>", $curFileB) || die "Error: $!";
		print(FB "\n" . $fullSign); 
		close(FB);
	}

	my($replyFinal, $z) = $self->Report();
	return($replyFinal, $z);
}

sub DESTROY {
        my($self) = shift;
        #printfv("Destroying %s %s",  $self, $self->name );
}

sub debug {
	my($self)  = shift;
	my($flag);

	if (ref $self && defined $self->{ _DEBUG }) {
		$flag = $self->{ _DEBUG };
	} else {
		# go looking for package variable
		no strict 'refs';
		$self = ref $self || $self;
		$flag = ${"$self\::DEBUG"};
	}

	return unless $flag;

	printf(STDERR "[%s] %s\n", $self->id, sprintf(shift @_, @_));
}


# Preloaded methods go here.

1;
__END__

=head1 NAME

EAFDSS::Base - base class for all other classes

=head1 DESCRIPTION

Nothing to describe nor to document here. Read EAFDSS::SDNP on how to use the module.

=head1 VERSION

This is version 0.10.

=head1 AUTHOR

Hasiotis Nikos, E<lt>hasiotis@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Hasiotis Nikos

This library is free software; you can redistribute it and/or modify
it under the terms of the LGPL or the same terms as Perl itself,
either Perl version 5.8.8 or, at your option, any later version of
Perl 5 you may have available.

=cut
