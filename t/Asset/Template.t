#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";

use WebGUI::Test;
use WebGUI::Session;
use WebGUI::Asset::Template;
use Exception::Class;
use Test::More tests => 11; # increment this value for each test you create
use Test::Deep;
use Data::Dumper;
use JSON qw{ to_json from_json };

my $session = WebGUI::Test->session;

my $list = WebGUI::Asset::Template->getList($session);
cmp_deeply($list, {}, 'getList with no classname returns an empty hashref');

my $template = " <tmpl_var variable> <tmpl_if conditional>true</tmpl_if> <tmpl_loop loop>XY</tmpl_loop> ";
my %var = (
	variable=>"BBBBB",
	conditional=>1,
	loop=>[{},{},{},{},{}]
	);

my $output = WebGUI::Asset::Template->processRaw($session,$template,\%var);
my $importNode = WebGUI::Asset::Template->getImportNode($session);
my $template = $importNode->addChild({className=>"WebGUI::Asset::Template", title=>"test", url=>"testingtemplates", template=>$template, namespace=>'WebGUI Test Template'});
isa_ok($template, 'WebGUI::Asset::Template', "creating a template");

is($template->get('parser'), 'WebGUI::Asset::Template::HTMLTemplate', 'default parser is HTMLTemplate');

$output = $template->process(\%var);
ok($output =~ m/\bBBBBB\b/, "process() - variables");
ok($output =~ m/true/, "process() - conditionals");
ok($output =~ m/\s(?:XY){5}\s/, "process() - loops");

# See if template listens the Accept header
my $request = $session->request;
my $in      = $request->headers_in;
my $out     = $request->headers_out;
$in->{Accept} = 'application/json';

my $json = $template->process(\%var);
my $andNowItsAPerlHashRef = eval { from_json( $json ) };
ok( !$@, 'Accept = json, JSON is returned' );
cmp_deeply( \%var, $andNowItsAPerlHashRef, 'Accept = json, The correct JSON is returned' );

# Done, so remove the json Accept header.
delete $session->request->headers_in->{Accept};

# Testing the stuff-your-variables-into-the-body-with-delimiters header
my $oldUser = $session->user;

# log in as admin so we pass canEdit
$session->user({ userId => 3 });
my $hname = 'X-Webgui-Template-Variables';
$in->{$hname} = $template->getId;

# processRaw sets some session variables (including username), so we need to
# re-do it.
WebGUI::Asset::Template->processRaw($session,$template,\%var);

# This has to get called to set up the stow good and proper
WebGUI::Asset::Template->processVariableHeaders($session);

$template->process(\%var);

my $output = WebGUI::Asset::Template->getVariableJson($session);

delete $in->{$hname};
my $start = delete $out->{"$hname-Start"};
my $end   = delete $out->{"$hname-End"};
my ($json) = $output =~ /\Q$start\E(.*)\Q$end\E/;
$andNowItsAPerlHashRef = eval { from_json( $json ) };
cmp_deeply( $andNowItsAPerlHashRef, \%var, "$hname: json returned correctly" )
    or diag "output: $output";

$session->user({ user => $oldUser });

# done testing the header stuff

my $newList = WebGUI::Asset::Template->getList($session, 'WebGUI Test Template');
ok(exists $newList->{$template->getId}, 'Uncommitted template exists returned from getList');

my $newList2 = WebGUI::Asset::Template->getList($session, 'WebGUI Test Template', "assetData.status='approved'");
ok(!exists $newList2->{$template->getId}, 'extra clause to getList prevents uncommitted template from being displayed');

$template->purge;

