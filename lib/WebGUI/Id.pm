package WebGUI::Id;


=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2004 Plain Black LLC.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use Digest::MD5;
use strict;
use Time::HiRes qw( gettimeofday usleep );
use WebGUI::Session;




=head1 NAME

Package WebGUI::Id

=head1 DESCRIPTION

This package generates global unique ids, sometimes called GUIDs. A global unique ID is guaranteed to be unique everywhere and at everytime.

NOTE: There is no such thing as perfectly unique ID's, but the chances of a duplicate ID are so minute that they are effectively unique.

=head1 SYNOPSIS

 use WebGUI::Id;

 my $id = WebGUI::Id::generate();

=head1 FUNCTIONS

These subroutines are available from this package:

=cut

#-------------------------------------------------------------------

=head2 generate

This function generates a global unique id.

=cut

sub generate {
  	my($s,$us)=gettimeofday();
  	my($v)=sprintf("%06d%10d%06d%255s",$us,$s,$$,$session{config}{defaultSiteName});
	return Digest::MD5::md5_base64($v);
}

1;


