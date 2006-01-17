package WebGUI::Asset::Template;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2006 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use HTML::Template;
use strict;
use WebGUI::Asset;
use WebGUI::SQL;
use WebGUI::Storage;

our @ISA = qw(WebGUI::Asset);


=head1 NAME

Package WebGUI::Asset::Template

=head1 DESCRIPTION

Provides a mechanism to provide a templating system in WebGUI.

=head1 SYNOPSIS

use WebGUI::Asset::Template;


=head1 METHODS

These methods are available from this class:

=cut


#-------------------------------------------------------------------
sub _execute {
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
	my $params = shift;
	my $vars = shift;
	my $t;
	eval {
		$t = HTML::Template->new(%{$params});
	};
	unless ($@) {
	        while (my ($section, $hash) = each %{ $session }) {
			next unless (ref $hash eq 'HASH');
        		while (my ($key, $value) = each %$hash) {
        	                unless (lc($key) eq "password" || lc($key) eq "identifier") {
                	        	$t->param("session.".$section.".".$key=>$value);
                        	}
	                }
        	} 
		$t->param(%{$vars});
		$t->param("webgui.version"=>$WebGUI::VERSION);
		$t->param("webgui.status"=>$WebGUI::STATUS);
		return $t->output;
	} else {
		$session->errorHandler->error("Error in template. ".$@);
		my $i18n = WebGUI::International->new($session, 'Asset_Template');
		return $i18n->get('template error').$@;
	}
}


#-------------------------------------------------------------------

=head2 definition ( definition )

Defines the properties of this asset.

=head3 definition

A hash reference passed in from a subclass definition.

=cut

sub definition {
        my $class = shift;
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
        my $definition = shift;
	my $i18n = WebGUI::International->new($session, 'Asset_Template');
        push(@{$definition}, {
		assetName=>$i18n->get('assetName'),
		icon=>'template.gif',
                tableName=>'template',
                className=>'WebGUI::Asset::Template',
                properties=>{
                                template=>{
                                        fieldType=>'codearea',
                                        defaultValue=>undef
                                        },
				isEditable=>{
					noFormPost=>1,
					fieldType=>'hidden',
					defaultValue=>1
					},
				showInForms=>{
					fieldType=>'yesNo',
					defaultValue=>1
				},
				namespace=>{
					fieldType=>'combo',
					defaultValue=>undef
					}
                        }
                });
        return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------

=head2 getEditForm ()

Returns the TabForm object that will be used in generating the edit page for this asset.

=cut

sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm();
	my $i18n = WebGUI::International->new($self->session, "Asset_Template");
	$tabform->hidden({
		name=>"returnUrl",
		value=>$self->session->form->process("returnUrl")
		});
	if ($self->getValue("namespace") eq "") {
		my $namespaces = $self->session->db->buildHashRef("select distinct(namespace),namespace 
			from template order by namespace");
		$tabform->getTab("properties")->combo(
			-name=>"namespace",
			-options=>$namespaces,
			-label=>$i18n->get('namespace'),
			-hoverHelp=>$i18n->get('namespace description'),
			-value=>[$self->session->form->process("namespace")] 
			);
	} else {
		$tabform->getTab("meta")->readOnly(
			-label=>$i18n->get('namespace'),
			-hoverHelp=>$i18n->get('namespace description'),
			-value=>$self->getValue("namespace")
			);	
		$tabform->getTab("meta")->hidden(
			-name=>"namespace",
			-value=>$self->getValue("namespace")
			);
	}
	$tabform->getTab("display")->yesNo(
		-name=>"showInForms",
		-value=>$self->getValue("showInForms"),
		-label=>$i18n->get('show in forms'),
		-hoverHelp=>$i18n->get('show in forms description'),
		);
        $tabform->getTab("properties")->codearea(
		-name=>"template",
		-label=>$i18n->get('assetName'),
		-hoverHelp=>$i18n->get('template description'),
		-value=>$self->getValue("template")
		);
	return $tabform;
}





#-------------------------------------------------------------------

=head2 getList ( session, namespace )

Returns a hash reference containing template ids and template names of all the templates in the specified namespace.

NOTE: This is a class method.

=head3 session

A reference to the current session.

=head3 namespace

Specify the namespace to build the list for.

=cut

sub getList {
	my $class = shift;
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
	my $namespace = shift;
my $sql = "select asset.assetId, assetData.revisionDate from template left join asset on asset.assetId=template.assetId left join assetData on assetData.revisionDate=template.revisionDate and assetData.assetId=template.assetId where template.namespace=".$session->db->quote($namespace)." and template.showInForms=1 and asset.state='published' and assetData.revisionDate=(SELECT max(revisionDate) from assetData where assetData.assetId=asset.assetId and (assetData.status='approved' or assetData.tagId=".$session->db->quote($session->scratch->get("versionTag")).")) order by assetData.title";
	my $sth = $session->dbSlave->read($sql);
	my %templates;
	tie %templates, 'Tie::IxHash';
	while (my ($id, $version) = $sth->array) {
		$templates{$id} = WebGUI::Asset::Template->new($session,$id,undef,$version)->getTitle;
	}	
	$sth->finish;	
	return \%templates;
}



#-------------------------------------------------------------------

=head2 process ( vars )

Evaluate a template replacing template commands for HTML.

=head3 vars

A hash reference containing template variables and loops. Automatically includes the entire WebGUI session.

=cut

sub process {
	my $self = shift;
	my $vars = shift;
	return $self->processRaw($self->session, $self->get("template"),$vars);
}


#-------------------------------------------------------------------

=head2 processRaw ( session, template, vars )

Evaluate a template replacing template commands for HTML. 

NOTE: This is a class method, no instance data required.

=head3 session

The session variable

=head3 template

A scalar variable containing the template.

=head3 vars

A hash reference containing template variables and loops. Automatically includes the entire WebGUI session.

=cut

sub processRaw {
	my $class = shift;
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
	my $template = shift;
	my $vars = shift;
	return _execute($session, {
		scalarref=>\$template,
		global_vars=>1,
   		loop_context_vars=>1,
		die_on_bad_params=>0,
		no_includes=>1,
		strict=>0 
		},$vars);
}


#-------------------------------------------------------------------
sub view {
	my $self = shift;
	if ($self->session->var->isAdminOn) {
		return $self->getToolbar;
	} else {
		return "";
	}
}


#-------------------------------------------------------------------
sub www_edit {
        my $self = shift;
        return $self->session->privilege->insufficient() unless $self->canEdit;
	$self->getAdminConsole->setHelp("template add/edit","Asset_Template");
	my $i18n = WebGUI::International->new($self->session, 'Asset_Template');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=styleWizard'),$i18n->get("style wizard")) if ($self->get("namespace") eq "style");
        return $self->getAdminConsole->render($self->getEditForm->print,$i18n->get('edit template'));
}

#-------------------------------------------------------------------
sub www_goBackToPage {
	my $self = shift;
	$self->session->http->setRedirect($self->session->form->process("returnUrl")) if ($self->session->form->process("returnUrl"));
	return "";
}


#-------------------------------------------------------------------
sub www_manage {
	my $self = shift;
	#takes the user to the folder containing this template.
	return $self->getParent->www_manageAssets;
}




#-------------------------------------------------------------------

sub www_styleWizard {
	my $self = shift;
        return $self->session->privilege->insufficient() unless $self->canEdit;
	my $output = "";
	if ($self->session->form->process("step") == 2) {
		my $f = WebGUI::HTMLForm->new($self->session,{action=>$self->getUrl});
		$f->hidden(name=>"func", value=>"styleWizard");
		$f->hidden(name=>"proceed", value=>"manageAssets") if ($self->session->form->process("proceed"));
		$f->hidden(name=>"step", value=>3);
		$f->hidden(name=>"layout", value=>$self->session->form->process("layout"));
		$f->text(name=>"heading", value=>"My Site", label=>"Site Name");
		$f->file(name=>"logo", label=>"Logo", subtext=>"<br />JPEG, GIF, or PNG thats less than 200 pixels wide and 100 pixels tall");
		$f->color(name=>"pageBackgroundColor", value=>"#ccccdd", label=>"Page Background Color");
		$f->color(name=>"headingBackgroundColor", value=>"#ffffff", label=>"Header Background Color");
		$f->color(name=>"headingForegroundColor", value=>"#000000", label=>"Header Text Color");
		$f->color(name=>"bodyBackgroundColor", value=>"#ffffff", label=>"Body Background Color");
		$f->color(name=>"bodyForegroundColor", value=>"#000000", label=>"Body Text Color");
		$f->color(name=>"menuBackgroundColor", value=>"#eeeeee", label=>"Menu Background Color");
		$f->color(name=>"linkColor", value=>"#0000ff", label=>"Link Color");
		$f->color(name=>"visitedLinkColor", value=>"#ff00ff", label=>"Visited Link Color");
		$f->submit;
		$output = $f->print;
	} elsif ($self->session->form->process("step") == 3) {
		my $storageId = $self->session->form->file("logo");
		my $logo;
		if ($storageId) {
			my $storage = WebGUI::Storage::Image->get($self->session,$self->session->form->file("logo"));
			$logo = $self->addChild({
				className=>"WebGUI::Asset::File::Image",
				title=>$self->session->form->text("heading")." Logo",
				menuTitle=>$self->session->form->text("heading")." Logo",
				url=>$self->session->form->text("heading")." Logo",
				storageId=>$storage->getId,
				filename=>@{$storage->getFiles}[0],
				templateId=>"PBtmpl0000000000000088"
				});
			$logo->generateThumbnail;
		}
my $style = '<html>
<head>
	<tmpl_var head.tags>
	<title>^Page(title); - ^c;</title>
	<style type="text/css">
	.siteFunctions {
		float: right;
		font-size: 12px;
	}
	.copyright {
		font-size: 12px;
	}
	body {
		background-color: '.$self->session->form->color("pageBackgroundColor").';
		font-family: helvetica;
		font-size: 14px;
	}
	.heading {
		background-color: '.$self->session->form->color("headingBackgroundColor").';
		color: '.$self->session->form->color("headingForegroundColor").';
		font-size: 30px;
		margin-left: 10%;
		margin-right: 10%;
		vertical-align: middle;
	}
	.logo {
		width: 200px; 
		float: left;
		text-align: center;
	}
	.logo img {
		border: 0px;
	}
	.endFloat {
		clear: both;
	}
	.padding {
		padding: 5px;
	}
	.bodyContent {
		background-color: '.$self->session->form->color("bodyBackgroundColor").';
		color: '.$self->session->form->color("bodyForegroundColor").';
		width: 55%; ';
if ($self->session->form->process("layout") == 1) {
	$style .= '
		float: left;
		height: 75%;
		margin-right: 10%;
		';
} else {
	$style .= '
		width: 80%;
		margin-left: 10%;
		margin-right: 10%;
		';
}
	$style .= '
	}
	.menu {
		background-color: '.$self->session->form->color("menuBackgroundColor").';
		width: 25%; ';
if ($self->session->form->process("layout") == 1) {
	$style .= '
		margin-left: 10%;
		height: 75%;
		float: left;
		';
} else {
	$style .= '
		width: 80%;
		text-align: center;
		margin-left: 10%;
		margin-right: 10%;
		';
}
	$style .= '
	}
	a {
		color: '.$self->session->form->color("linkColor").';
	}
	a:visited {
		color: '.$self->session->form->color("visitedLinkColor").';
	}
	</style>
</head>
<body>
^AdminBar;
<div class="heading">
	<div class="padding">
';
	if (defined $logo) {
		$style .= '<div class="logo"><a href="^H(linkonly);">^AssetProxy('.$logo->get("url").');</a></div>';
	}
	$style .= '
		'.$self->session->form->text("heading").'
		<div class="endFloat"></div>
	</div>
</div>
<div class="menu">
	<div class="padding">^AssetProxy('.($self->session->form->process("layout") == 1 ? 'flexmenu' : 'toplevelmenuhorizontal').');</div>
</div>
<div class="bodyContent">
	<div class="padding"><tmpl_var body.content></div>
</div>';
if ($self->session->form->process("layout") == 1) {
	$style .= '<div class="endFloat"></div>';
}
$style .= '
<div class="heading">
	<div class="padding">
		<div class="siteFunctions">^a(^@;); ^AdminToggle;</div>
		<div class="copyright">&copy; ^D(%y); ^c;</div>
	<div class="endFloat"></div>
	</div>
</div>
</body>
</html>';
		return $self->addRevision({
			template=>$style
			})->www_edit;
	} else {
		$output = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl}).WebGUI::Form::hidden($self->session,{name=>"func", value=>"styleWizard"});
		$output .= WebGUI::Form::hidden($self->session,{name=>"proceed", value=>"manageAssets"}) if ($self->session->form->process("proceed"));
		$output .= '<style type="text/css">
			.chooser { float: left; width: 150px; height: 150px; } 
			.representation, .representation td { font-size: 12px; width: 120px; border: 1px solid black; } 
			.representation { height: 130px; }
			</style>';
		$output .= "<p>Choose a layout for this style:</p>";
		$output .= WebGUI::Form::hidden($self->session,{name=>"step", value=>2});
		$output .= '<div class="chooser">'.WebGUI::Form::radio($self->session,{name=>"layout", value=>1, checked=>1}).q|<table class="representation"><tbody>
			<tr><td>Logo</td><td>Heading</td></tr>
			<tr><td>Menu</td><td>Body content goes here.</td></tr>
			</tbody></table></div>|;
		$output .= '<div class="chooser">'.WebGUI::Form::radio($self->session,{name=>"layout", value=>2}).q|<table class="representation"><tbody>
			<tr><td>Logo</td><td>Heading</td></tr>
			<tr><td style="text-align: center;" colspan="2">Menu</td></tr>
			<tr><td colspan="2">Body content goes here.</td></tr>
			</tbody></table></div>|;
		$output .= WebGUI::Form::submit($self->session,);
		$output .= WebGUI::Form::formFooter($self->session,);
	}
	my $i18n = WebGUI::International->new($self->session, 'Asset_Template');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=edit'),$i18n->get("edit template")) if ($self->get("url"));
        return $self->getAdminConsole->render($output,$i18n->get('style wizard'));
}

#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	return $self->getContainer->www_view;
}



1;

