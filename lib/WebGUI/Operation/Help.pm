package WebGUI::Operation::Help;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2002 Plain Black LLC.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use Exporter;
use strict;
use Tie::IxHash;
use Tie::CPHash;
use WebGUI::HTMLForm;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::URL;
use WebGUI::Utility;

our @ISA = qw(Exporter);
our @EXPORT = qw(&www_viewHelp &www_viewHelpIndex &www_manageHelp &www_editHelp &www_editHelpSave 
	&www_exportHelp &www_deleteHelp &www_deleteHelpConfirm);

#-------------------------------------------------------------------
sub _helpLink {
	return '<a href="'.WebGUI::URL::page('op=viewHelp&hid='.$_[0].'&namespace='.$_[1]).'">'.$_[2].'</a>';
}

#-------------------------------------------------------------------
sub _seeAlso {
	my ($item, $seeAlso, @items, $namespace, $helpId, $titleId, $output);
	$seeAlso = $_[0];
	$seeAlso =~ s/\n//g; #removes line feeds
	$seeAlso =~ s/\r//g; #removes carriage returns
	$seeAlso =~ s/ //g; #removes spaces
	@items = split(/;/,$seeAlso);
	foreach $item (@items) {
		($helpId,$namespace) = split(/,/,$item);
		($titleId) = WebGUI::SQL->quickArray("select titleId from help where helpId=$helpId 
			and namespace='$namespace'");
		$output .= '<li>'._helpLink($helpId,$namespace,WebGUI::International::get($titleId,$namespace));
	}
	return $output;
}

#-------------------------------------------------------------------
sub www_deleteHelp {
	if ($session{user}{userId} != 3) {
                return "";
        } else {
		my $output = '<h1>Confirm</h1>Are you sure? Deleting help is never a good idea. <a href="'
			.WebGUI::URL::page("op=deleteHelpConfirm&hid=".$session{form}{hid}."&namespace=".$session{form}{namespace})
			.'">Yes</a> / <a href="'.WebGUI::URL::page("op=manageHelp").'">No</a><p>';
		return $output;
	}
}

#-------------------------------------------------------------------
sub www_deleteHelpConfirm {
	if ($session{user}{userId} != 3) {
                return "";
        } else {
		my ($titleId, $bodyId) = WebGUI::SQL->quickArray("select titleId,bodyId from help where helpId=".$session{form}{hid}."
			and namespace=".quote($session{form}{namespace}));
		WebGUI::SQL->write("delete from international where internationalId=$titleId
			and namespace=".quote($session{form}{namespace}));
		WebGUI::SQL->write("delete from international where internationalId=$bodyId
			and namespace=".quote($session{form}{namespace}));
		WebGUI::SQL->write("delete from help where helpId=".$session{form}{hid}." 
			and namespace=".quote($session{form}{namespace}));
		return www_manageHelp();
	}
}

#-------------------------------------------------------------------
sub www_editHelp {
	if ($session{user}{userId} != 3) {
                return "";
        } else {
		my ($output, $f, %data, %help, @seeAlso);
		tie %data, 'Tie::IxHash';
		tie %help, 'Tie::CPHash';
		if ($session{form}{hid} ne "new") {
			%help = WebGUI::SQL->quickHash("select * from help where 
				helpId=$session{form}{hid} and namespace=".quote($session{form}{namespace}));
			$help{title} = WebGUI::International::get($help{titleId},$help{namespace});
			$help{body} = WebGUI::International::get($help{bodyId},$help{namespace});
			$help{seeAlso} =~ s/\n//g;
			$help{seeAlso} =~ s/\r//g;
			$help{seeAlso} =~ s/ //g;
			@seeAlso = split(/;/,$help{seeAlso});
		} else {
			$help{titleId} = "new";
			$help{bodyId} = "new";
			$help{namespace} = "WebGUI";
		}
		$output = '<h1>Edit Help</h1>';
		$f = WebGUI::HTMLForm->new();
		$f->hidden("op","editHelpSave");
		$f->hidden("hid",$session{form}{hid});
		$f->readOnly($session{form}{hid},"Help ID");
		if ($session{form}{hid} eq "new") {
			%data = WebGUI::SQL->buildHash("select namespace,namespace from help order by namespace");
			$f->combo("namespace",\%data,"Namespace",[$help{namespace}]);
		} else {
			$f->hidden("namespace",$session{form}{namespace});
			$f->readOnly($session{form}{namespace},"Namespace");
		}
		$f->hidden("titleId",$help{titleId});
		$f->readOnly($help{titleId},"Title ID");
		$f->text("title","Title",$help{title});
		$f->hidden("bodyId",$help{bodyId});
		$f->readOnly($help{bodyId},"Body ID");
		$f->HTMLArea("body","Body",$help{body},'','','',20,60);
		%data = WebGUI::SQL->buildHash("select concat(help.helpId,',',help.namespace),
			concat(international.message,' (',help.helpId,'/',help.namespace,')')
			from help,international where help.titleId=international.internationalId 
			and help.namespace=international.namespace and international.languageId=1 order by international.message");
		$f->select("seeAlso",\%data,"See Also",\@seeAlso,8,1);
		$f->submit;
		$output .= $f->print;
		return $output;
	}
}

#-------------------------------------------------------------------
sub www_editHelpSave {
	if ($session{user}{userId} != 3) {
                return "";
        } else {
		my (@seeAlso);
		if ($session{form}{hid} eq "new") {
			if ($session{form}{namespace_new} ne "") {
				$session{form}{namespace} = $session{form}{namespace_new};
			}
			($session{form}{titleId}) = WebGUI::SQL->quickArray("select max(internationalId) from international
				where namespace=".quote($session{form}{namespace}));
			$session{form}{titleId}++;
			$session{form}{bodyId} = $session{form}{titleId}+1;
			($session{form}{hid}) = WebGUI::SQL->quickArray("select max(helpId) from help 
				where namespace=".quote($session{form}{namespace}));
			$session{form}{hid}++;
			WebGUI::SQL->write("insert into international (internationalId,languageId,namespace) values 
				($session{form}{titleId},1,".quote($session{form}{namespace}).")");
			WebGUI::SQL->write("insert into international (internationalId,languageId,namespace) values 
				($session{form}{bodyId},1,".quote($session{form}{namespace}).")");
			WebGUI::SQL->write("insert into help (helpId,namespace,titleId,bodyId) values 
				($session{form}{hid},".quote($session{form}{namespace}).",$session{form}{titleId},
				$session{form}{bodyId})");
		}
		@seeAlso = $session{cgi}->param('seeAlso');
		if ($seeAlso[0] ne "") {
			$session{form}{seeAlso} = join(";",@seeAlso);
			$session{form}{seeAlso} .= ';';
		}
		WebGUI::SQL->write("update international set message=".quote($session{form}{title}).", lastUpdated=".time()." 
			where internationalId=$session{form}{titleId} and languageId=1 and namespace=".quote($session{form}{namespace}));
		WebGUI::SQL->write("update international set message=".quote($session{form}{body}).", lastUpdated=".time()."
			where internationalId=$session{form}{bodyId} and languageId=1 and namespace=".quote($session{form}{namespace}));
		WebGUI::SQL->write("update help set seeAlso=".quote($session{form}{seeAlso})." 
			where helpId=$session{form}{hid} and namespace=".quote($session{form}{namespace}));
		return www_manageHelp();
	}
}

#-------------------------------------------------------------------
sub www_exportHelp {
	return "" if ($session{user}{userId} != 3);
	my ($export, $output, %help, $sth);
	$export = "#export of WebGUI ".$WebGUI::VERSION." help system.\n\n";
	$sth = WebGUI::SQL->read("select * from help");
	while (%help = $sth->hash) {
		$export .= "delete from help where helpId=$help{helpId} and namespace=".quote($help{namespace}).";\n";
		$export .= "insert into help (helpId,namespace,titleId,bodyId,seeAlso) values ($help{helpId}, "
			.quote($help{namespace}).", $help{titleId}, $help{bodyId}, ".quote($help{seeAlso}).");\n";
	}
	$sth->finish;
	$session{header}{mimetype} = 'text/plain';
	return $export;
}

#-------------------------------------------------------------------
sub www_manageHelp {
        my ($sth, @help, $output);
	if ($session{user}{userId} != 3) {	
		return "";
	} else {
        	$output = '<h1>Manage Help</h1>';
		$output .= 'This interface is for WebGUI developers only. If you\'re not a developer, leave this alone. Also, 
			this interface works <b>ONLY</b> under MySQL and is not supported by Plain Black under any
			circumstances.<p>';
		$output .= '<a href="'.WebGUI::URL::page('op=editHelp&hid=new').'">Add new help.</a>';
		$output .= ' &middot; ';
		$output .= '<a href="'.WebGUI::URL::page('op=exportHelp').'">Export help.</a>';
		$output .= '<p><table class="tableData">';
        	$sth = WebGUI::SQL->read("select help.helpId,help.namespace,international.message from help,international 
			where help.titleId=international.internationalId and help.namespace=international.namespace 
			and international.languageId=1 order by international.message");
        	while (@help = $sth->array) {
			$output .= '<tr><td>'
				.deleteIcon("op=deleteHelp&hid=".$help[0]."&namespace=".$help[1])
				.editIcon("op=editHelp&hid=".$help[0]."&namespace=".$help[1])
				.'</td>'
				.'<td>'._helpLink($help[0],$help[1],$help[2]).'</td>'
				.'<td>'.$help[0].'/'.$help[1].'</td>'
				.'</tr>';	
		}
        	$sth->finish;
        	$output .= '</table>';
        	return $output;
	}
}

#-------------------------------------------------------------------
sub www_viewHelp {
        my ($output, %help, $namespace);
	$namespace = $session{form}{namespace} || "WebGUI";
	tie %help, 'Tie::CPHash';
	%help = WebGUI::SQL->quickHash("select * from help where helpId=$session{form}{hid} and namespace='$namespace'");
        $output = '<h1>'.WebGUI::International::get(93).': '.
		WebGUI::International::get($help{titleId},$help{namespace}).'</h1>';
	$output .= WebGUI::International::get($help{bodyId},$help{namespace});
	$output .= '<p><b>'.WebGUI::International::get(94).':<ul>';
	$output .= _seeAlso($help{seeAlso});
        $output .= '<li><a href="'.WebGUI::URL::page('op=viewHelpIndex').'">'.WebGUI::International::get(95).'</a></ul>';
        return $output;
}

#-------------------------------------------------------------------
sub www_viewHelpIndex {
	my ($sth, %help, $output, $key, %index, $title, $seeAlso, %sortedIndex, $i, $midpoint);
	tie %help, 'Tie::CPHash';
	tie %sortedIndex, 'Tie::IxHash';
	$output = '<h1>'.WebGUI::International::get(95).'</h1>';
	$sth = WebGUI::SQL->read("select helpId,namespace,titleId,seeAlso from help");
	while (%help = $sth->hash) {
		$title = WebGUI::International::get($help{titleId},$help{namespace});
		$index{$title} = _helpLink($help{helpId},$help{namespace},$title);
		$seeAlso = _seeAlso($help{seeAlso});
		if ($seeAlso ne "") {
			$index{$title} .= '<span style="font-size: 11px"><ul>'.$seeAlso.'</ul></span>';
		}
		$i++;
	}
	$midpoint = round($i/2);
	$sth->finish;
	foreach $key (sort {$a cmp $b} keys %index) {
                $sortedIndex{$key}=$index{$key};
        }
	$i = 0;
	$output .= '<table width="100%"><tr><td width="50%" valign="top" class="content">';
	foreach $key (keys %sortedIndex) {
		if ($i == $midpoint) {
			$output .= '</td><td width="50%" valign="top" class="content">';
		}
		$output .= $sortedIndex{$key}.'<p>';
		$i++;
	}
	$output .= '</table>';
	return $output;
}

1;

