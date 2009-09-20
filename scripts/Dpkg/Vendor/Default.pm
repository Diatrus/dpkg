# Copyright © 2009 Raphaël Hertzog <hertzog@debian.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package Dpkg::Vendor::Default;

use strict;
use warnings;

# If you use this file as template to create a new vendor object, please
# uncomment the following lines
#use Dpkg::Vendor::Default;
#our @ISA = qw(Dpkg::Vendor::Default);

=head1 NAME

Dpkg::Vendor::Default - default vendor object

=head1 DESCRIPTION

A vendor object is used to provide vendor specific behaviour
in various places. This is the default object used in case
there's none for the current vendor or in case the vendor could
not be identified (see Dpkg::Vendor documentation).

It provides some hooks that are called by various dpkg-* tools.
If you need a new hook, please file a bug against dpkg-dev and explain
your need. Note that the hook API has no guaranty to be stable over an
extended period. If you run an important distribution that makes use
of vendor hooks, you'd better submit them for integration so that
we avoid breaking your code.

=head1 FUNCTIONS

=over 4

=item $vendor_obj = Dpkg::Vendor::Default->new()

Creates the default vendor object. Can be inherited by all vendor objects
if they don't need any specific initialization at object creation time.

=cut

sub new {
    my ($this) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return $self;
}

=item $vendor_obj->run_hook($id, @params)

Run the corresponding hook. The parameters are hook-specific. The
supported hooks are:

=over 8

=item before-source-build ($srcpkg)

The first parameter is a Dpkg::Source::Package object. The hook is called
just before the execution of $srcpkg->build().

=item before-changes-creation ($fields)

The hook is called just before the content of .changes file is output
by dpkg-genchanges. The first parameter is a Dpkg::Control object
representing all the fields that are going to be output.

=item keyrings ()

The hook is called when dpkg-source is checking a signature on a source
package. It takes no parameters, but returns a (possibly empty) list of
vendor-specific keyrings.

=item register-custom-fields ()

The hook is called in Dpkg::Control::Fields to register custom fields.
You should return a list of arrays. Each array is an operation to perform.
The first item is the name of the operation and corresponds
to a field_* function provided by Dpkg::Control::Fields. The remaining
fields are the parameters that are passed unchanged to the corresponding
function.

Known operations are "register", "insert_after" and "insert_before".

=item post-process-changelog-entry ($fields)

The hook is called in Dpkg::Changelog to post-process a
Dpkg::Changelog::Entry after it has been created and filled with the
appropriate values.

=back

=cut

sub run_hook {
    my ($self, $hook, @params) = @_;

    if ($hook eq "before-source-build") {
        my $srcpkg = shift @params;
    } elsif ($hook eq "before-changes-creation") {
        my $fields = shift @params;
    } elsif ($hook eq "keyrings") {
        return ();
    } elsif ($hook eq "register-custom-fields") {
        return ();
    } elsif ($hook eq "post-process-changelog-entry") {
        my $fields = shift @params;
    }

}

=back

=cut

1;
