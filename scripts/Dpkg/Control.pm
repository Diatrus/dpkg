# Copyright © 2007-2009 Raphaël Hertzog <hertzog@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package Dpkg::Control;

use strict;
use warnings;

use Dpkg::Gettext;
use Dpkg::ErrorHandling;
use Dpkg::Fields qw(capit);
use Dpkg::Control::Types;
use Dpkg::Control::Hash;

use base qw(Dpkg::Control::Hash Exporter);
our @EXPORT = qw(parsecdata CTRL_UNKNOWN CTRL_INFO_SRC CTRL_INFO_PKG CTRL_APT_SRC
                 CTRL_APT_PKG CTRL_PKG_SRC CTRL_PKG_DEB CTRL_FILE_CHANGES
                 CTRL_FILE_VENDOR CTRL_FILE_STATUS CTRL_CHANGELOG);

=head1 NAME

Dpkg::Control - parse and manipulate official control-like information

=head1 DESCRIPTION

The Dpkg::Control object is a smart version of Dpkg::Control::Hash.
It associates a type to the control information. That type can be
used to know what fields are allowed and in what order they must be
output.

The types are constants that are exported by default. Here's the full
list:

=over 4

=item CTRL_UNKNOWN

This type is the default type, it indicates that the type of control
information is not yet known.

=item CTRL_INFO_SRC

Corresponds to the first block of information in a debian/control file in
a Debian source package.

=item CTRL_INFO_PKG

Corresponds to subsequent blocks of information in a debian/control file
in a Debian source package.

=item CTRL_APT_SRC

Corresponds to an entry in a Sources file of an APT source package
repository.

=item CTRL_APT_PKG

Corresponds to an entry in a Packages file of an APT binary package
repository.

=item CTRL_PKG_SRC

Corresponds to a .dsc file of a Debian source package.

=item CTRL_PKG_DEB

Corresponds to the control file generated by dpkg-gencontrol
(DEBIAN/control) and to the same file inside .deb packages.

=item CTRL_FILE_CHANGES

Corresponds to a .changes file.

=item CTRL_FILE_VENDOR

Corresponds to a vendor file in /etc/dpkg/origins/.

=item CTRL_FILE_STATUS

Corresponds to an entry in dpkg's status file (/var/lib/dpkg/status).

=item CTRL_CHANGELOG

Corresponds to the output of dpkg-parsechangelog.

=back

=head1 FUNCTIONS

All the methods of Dpkg::Control::Hash are available. Those listed below
are either new or overriden with a different behaviour.

=over 4

=item $obj = Dpkg::Control::parsecdata($input, $file, %options)

$input is a filehandle, $file is the name of the file corresponding to
$input. %options can contain two parameters: allow_pgp=>1 allows the parser
to extrac the block of a data in a PGP-signed message (defaults to 0),
and allow_duplicate=>1 ask the parser to not fail when it detects
duplicate fields.

The return value is a reference to a tied hash (Dpkg::Fields::Object) that
can be used to access the various fields.

=cut

sub parsecdata {
    my ($input, $file, %options) = @_;

    $options{allow_pgp} = 0 unless exists $options{allow_pgp};
    $options{allow_duplicate} = 0 unless exists $options{allow_duplicate};

    my $paraborder = 1;
    my $fields = undef;
    my $cf = ''; # Current field
    my $expect_pgp_sig = 0;
    while (<$input>) {
	s/\s*\n$//;
	next if (m/^$/ and $paraborder);
	next if (m/^#/);
	$paraborder = 0;
	if (m/^(\S+?)\s*:\s*(.*)$/) {
	    unless (defined $fields) {
		my %f;
		tie %f, "Dpkg::Fields::Object";
		$fields = \%f;
	    }
	    if (exists $fields->{$1}) {
		unless ($options{allow_duplicate}) {
		    syntaxerr($file, sprintf(_g("duplicate field %s found"), capit($1)));
		}
	    }
	    $fields->{$1} = $2;
	    $cf = $1;
	} elsif (m/^\s+\S/) {
	    length($cf) || syntaxerr($file, _g("continued value line not in field"));
	    $fields->{$cf} .= "\n$_";
	} elsif (m/^-----BEGIN PGP SIGNED MESSAGE/) {
	    $expect_pgp_sig = 1;
	    if ($options{allow_pgp}) {
		# Skip PGP headers
		while (<$input>) {
		    last if m/^$/;
		}
	    } else {
		syntaxerr($file, _g("PGP signature not allowed here"));
	    }
	} elsif (m/^$/) {
	    if ($expect_pgp_sig) {
		# Skip empty lines
		$_ = <$input> while defined($_) && $_ =~ /^\s*$/;
		length($_) ||
                    syntaxerr($file, _g("expected PGP signature, found EOF after blank line"));
		s/\n$//;
		m/^-----BEGIN PGP SIGNATURE/ ||
		    syntaxerr($file,
			sprintf(_g("expected PGP signature, found something else \`%s'"), $_));
		# Skip PGP signature
		while (<$input>) {
		    last if m/^-----END PGP SIGNATURE/;
		}
		length($_) ||
                    syntaxerr($file, _g("unfinished PGP signature"));
	    }
	    last; # Finished parsing one block
	} else {
	    syntaxerr($file, _g("line with unknown format (not field-colon-value)"));
	}
    }
    return $fields;
}

=item my $c = Dpkg::Control->new(%opts)

If the "type" option is given, it's used to setup default values
for other options. See set_options() for more details.

=cut

sub new {
    my ($this, %opts) = @_;
    my $class = ref($this) || $this;

    my $self = Dpkg::Control::Hash->new();
    bless $self, $class;
    $self->set_options(%opts);

    return $self;
}

=item $c->set_options(%opts)

Changes the value of one or more options. If the "type" option is changed,
it is used first to define default values for others options. The option
"allow_pgp" is set to 1 for CTRL_PKG_SRC and CTRL_FILE_CHANGES and to 0
otherwise. The option "drop_empty" is set to 0 for CTRL_INFO_PKG and
CTRL_INFO_SRC and to 1 otherwise. The option "name" is set to a textual
description of the type of control information.

The output order is also set to match the ordered list returned by
Dpkg::Control::Fields::field_ordered_list($type).

=cut

sub set_options {
    my ($self, %opts) = @_;
    if (exists $opts{'type'}) {
        my $t = $opts{'type'};
        $$self->{'allow_pgp'} = ($t & (CTRL_PKG_SRC | CTRL_FILE_CHANGES)) ? 1 : 0;
        $$self->{'drop_empty'} = ($t & (CTRL_INFO_PKG | CTRL_INFO_SRC)) ?  0 : 1;
        if ($t == CTRL_INFO_SRC) {
            $$self->{'name'} = _g("general section of control info file");
        } elsif ($t == CTRL_INFO_PKG) {
            $$self->{'name'} = _g("package's section of control info file");
        } elsif ($t == CTRL_CHANGELOG) {
            $$self->{'name'} = _g("parsed version of changelog");
        } elsif ($t == CTRL_APT_SRC) {
            $$self->{'name'} = sprintf(_g("entry of APT's %s file"), "Sources");
        } elsif ($t == CTRL_APT_PKG) {
            $$self->{'name'} = sprintf(_g("entry of APT's %s file"), "Packages");
        } elsif ($t == CTRL_PKG_SRC) {
            $$self->{'name'} = sprintf(_g("%s file"), ".dsc");
        } elsif ($t == CTRL_PKG_DEB) {
            $$self->{'name'} = _g("control info of a .deb package");
        } elsif ($t == CTRL_FILE_CHANGES) {
            $$self->{'name'} = sprintf(_g("%s file"), ".changes");
        } elsif ($t == CTRL_FILE_VENDOR) {
            $$self->{'name'} = _g("vendor file");
        } elsif ($t == CTRL_FILE_STATUS) {
            $$self->{'name'} = _g("entry in dpkg's status file");
        }
    }

    # Options set by the user override default values
    $$self->{$_} = $opts{$_} foreach keys %opts;
}

=item $c->get_type()

Returns the type of control information stored. See the type parameter
set during new().

=cut

sub get_type {
    my ($self) = @_;
    return $$self->{'type'};
}

=back

=head1 AUTHOR

Raphaël Hertzog <hertzog@debian.org>.

=cut

1;
