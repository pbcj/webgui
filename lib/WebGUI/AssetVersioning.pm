package WebGUI::Asset;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::Session;

=head1 NAME

Package WebGUI::AssetVersioning

=head1 DESCRIPTION

This is a mixin package for WebGUI::Asset that contains all versioning related functions.

=head1 SYNOPSIS

 use WebGUI::Asset;

=head1 METHODS

These methods are available from this class:

=cut


#-------------------------------------------------------------------

=head2 addRevision ( properties [ , revisionDate ] )

Adds a revision of an existing asset. Note that programmers should almost never call this method directly, but rather use the update() method instead.

=head3 properties

A hash reference containing a list of properties to associate with the child. 
        
=head3 revisionDate

An epoch date representing the date/time stamp that this revision was created. Defaults to time().
        
=cut    
        
sub addRevision {
        my $self = shift;
        my $properties = shift;
	my $now = shift || time();
	my $versionTag = $session{scratch}{versionTag} || 'pbversion0000000000002';
	my $status = $session{setting}{autoCommit} ? 'approved' : 'pending';
	WebGUI::SQL->write("insert into assetData (assetId, revisionDate, revisedBy, tagId, status, url, startDate, endDate, 
		ownerUserId, groupIdEdit, groupIdView) values (".quote($self->getId).",".$now.", ".quote($session{user}{userId}).", 
		".quote($versionTag).", ".quote($status).", ".quote($self->getId).", 997995720, 9223372036854775807,'3','3','7')");
        foreach my $definition (@{$self->definition}) {
                unless ($definition->{tableName} eq "assetData") {
                        WebGUI::SQL->write("insert into ".$definition->{tableName}." (assetId,revisionDate) values (".quote($self->getId).",".$now.")");
                }
        }               
        my $newVersion = WebGUI::Asset->new($self->getId, $self->get("className"), $now);
        $newVersion->updateHistory("created revision");
        $newVersion->update($properties);
	$newVersion->setVersionLock unless ($session{setting}{autoCommit});
        return $newVersion;
}

#-------------------------------------------------------------------

=head2 addVersionTag ( [ name ] ) 

A class method. Creates a version tag and assigns the tag to the current user's version tag. Returns the id of the tag created.

=head3 name

The name of the version tag. If not specified, one will be generated using the current user's name along with the date.

=cut

sub addVersionTag {
	my $class = shift;
	my $name = shift || "Autotag created ".WebGUI::DateTime::epochToHuman()." by ".$session{user}{username};
	my $tagId = WebGUI::SQL->setRow("assetVersionTag","tagId",{
		tagId=>"new",
		name=>$name,
		creationDate=>time(),
		createdBy=>$session{user}{userId}
		});
	WebGUI::Session::setScratch("versionTag",$tagId);
	return $tagId;
} 


#-------------------------------------------------------------------

sub commit {
	my $self = shift;
	$self->unsetVersionLock;
	WebGUI::SQL->write("update assetData set status='approved' where assetId=".quote($self->getId)." and revisionDate=".quote($self->get("revisionDate")));
	$self->purgeCache;
}

#-------------------------------------------------------------------

sub commitVersionTag {
	my $class = shift;
	my $tagId = shift;
	my $sth = WebGUI::SQL->read("select asset.assetId,asset.className,assetData.revisionDate from assetData left join asset on asset.assetId=assetData.assetId where assetData.tagId=".quote($tagId));
	while (my ($id,$class,$version) = $sth->array) {
		WebGUI::Asset->new($id,$class,$version)->commit;
	}
	$sth->finish;
	WebGUI::SQL->write("update assetVersionTag set isCommitted=1, commitDate=".time().", committedBy=".quote($session{user}{userId})." where tagId=".quote($tagId));
	WebGUI::SQL->write("delete from userSessionScratch where name='versionTag' and value=".quote($tagId));
}


#-------------------------------------------------------------------

=head2 getRevisionCount ( [ status ] )

Returns the number of revisions available for this asset.

=head3 status

Optionally specify to get the count based upon the status of the revisions. Options are "approved", "pending", "denied". Defaults to any status.

=cut

sub getRevisionCount {
	my $self = shift;
	my $status = shift;
	my $statusClause = " and status=".quote($status) if ($status);
	my ($count) = WebGUI::SQL->quickArray("select count(*) from assetData where assetId=".quote($self->getId).$statusClause);
	return $count;
}


#-------------------------------------------------------------------

=head2 isLocked ( )

Returns a boolean indicating whether the asset is locked for editing by the versioning system.

=cut

sub isLocked {
	my $self = shift;
	return $self->get("isLockedBy") ? 1 : 0;
}


#-------------------------------------------------------------------

=head2 purgeRevision ( )

Deletes a revision of an asset. If it's the last revision, it purges the asset all together.

=cut

sub purgeRevision {
	my $self = shift;
	if ($self->getRevisionCount > 1) {
		WebGUI::SQL->beginTransaction;
        	foreach my $definition (@{$self->definition}) {                
			WebGUI::SQL->write("delete from ".$definition->{tableName}." where assetId=".quote($self->getId)." and revisionDate=".quote($self->get("revisionDate")));
        	}       
        	WebGUI::SQL->commit;
		$self->purgeCache;
		$self->updateHistory("purged revision ".$self->get("revisionDate"));
	} else {
		$self->purge;
	}
}


#-------------------------------------------------------------------

=head2 rollbackSiteToTime ( time ) 

A class method. Rollback the entire site to a specific point in time. Returns 1 if successful.

=head3 time

The epoch time to rollback to. Anything after this time will be permanently deleted.

=cut

sub rollbackToTime {
	my $class = shift;
	my $toTime = shift;
 	unless ($toTime) {	
		return 0;
		WebGUI::ErrorHandler::warn("You must specify a time when you call rollbackSiteToTime().");
	}
	my $sth = WebGUI::SQL->read("select asset.className, asset.assetId, assetData.revisionDate from assetData left join asset on asset.assetId=assetData.assetId where assetData.revisionDate > ".$toTime." order by assetData.revisionDate desc");
	while (my ($class, $id, $revisionDate) = $sth->array) {
		my $revision = WebGUI::Asset->new($id, $class, $revisionDate);
		$revision->purgeRevision;
	}
	$sth->finish;
	return 1;
}

#-------------------------------------------------------------------

=head2 rollbackVersionTag ( tagId )

A class method. Eliminates all revisions of all assets created under a specific version tag. Also removes the version tag.

=head3 tagId

The unique identifier of the version tag to be purged.

=cut

sub rollbackVersionTag {
	my $class = shift;
	my $tagId = shift;
 	unless ($tagId) {	
		return 0;
		WebGUI::ErrorHandler::warn("You must specify a tag ID when you call rollbackVersionTag().");
	}
	if ($tagId eq "pbversion0000000000001" || $tagId eq "pbversion0000000000002") {
		return 0;
		WebGUI::ErrorHandler::warn("You cannot rollback a tag that is required for the system to operate.");	
	}
	my $sth = WebGUI::SQL->read("select asset.className, asset.assetId, assetData.revisionDate from assetData left join asset on asset.assetId=assetData.assetId where assetData.tagId = ".quote($tagId)." order by assetData.revisionDate desc");
	while (my ($class, $id, $revisionDate) = $sth->array) {
		my $revision = WebGUI::Asset->new($id, $class, $revisionDate);
		$revision->purgeRevision;
	}
	$sth->finish;
	WebGUI::SQL->write("delete from assetVersionTag where tagId=".quote($tagId));
	WebGUI::SQL->write("delete from userSessionScratch where name='versionTag' and value=".quote($tagId));
	return 1;
}


#-------------------------------------------------------------------

=head2 setVersionLock ( ) 

Sets the versioning lock to "on" so that this piece of content may not be edited by anyone else now that it has been edited.

=cut

sub setVersionLock {
	my $self = shift;
	WebGUI::SQL->write("update asset set isLockedBy=".quote($session{user}{userId})." where assetId=".quote($self->getId));
	$self->updateHistory("locked");
	$self->purgeCache;
}


#-------------------------------------------------------------------

=head2 unsetVersionLock ( ) 

Sets the versioning lock to "off" so that this piece of content may be edited once again.

=cut

sub unsetVersionLock {
	my $self = shift;
	WebGUI::SQL->write("update asset set isLockedBy=NULL where assetId=".quote($self->getId));
	$self->updateHistory("unlocked");
	$self->purgeCache;
}


#-------------------------------------------------------------------

=head2 updateHistory ( action [,userId] )

Updates the assetHistory table with the asset, user, action, and timestamp.

=head3 action

String representing type of action taken on an Asset.

=head3 userId

If not specified, current user is used.

=cut

sub updateHistory {
	my $self = shift;
	my $action = shift;
	my $userId = shift || $session{user}{userId} || '3';
	my $dateStamp = time();
	WebGUI::SQL->write("insert into assetHistory (assetId, userId, actionTaken, dateStamp) values (".quote($self->getId).", ".quote($userId).", ".quote($action).", ".$dateStamp.")");
}


#-------------------------------------------------------------------

=head2 www_addVersionTag ()

Displays the add version tag form.

=cut

sub www_addVersionTag {
	my $self = shift;
	my $ac = WebGUI::AdminConsole->new("versions");
        return WebGUI::Privilege::insufficient() unless (WebGUI::Grouping::isInGroup(12));
	my $i18n = WebGUI::International->new("Asset");
        $ac->addSubmenuItem($self->getUrl('func=manageVersions'), $i18n->get("manage versions"));
	my $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
	my $tag = WebGUI::SQL->getRow("assetVersionTag","tagId",$session{form}{tagId});
	$f->hidden(
		-name=>"func",
		-value=>"addVersionTagSave"
		);
	$f->text(
		-name=>"name",
		-label=>"Version Tag Name",
		-value=>$tag->{name}
		);
	$f->submit;
        return $ac->render($f->print,$i18n->get("add version tag"));	
}


#-------------------------------------------------------------------

=head2 www_addVersionTagSave ()

Adds a version tag and sets the user's default version tag to that.

=cut

sub www_addVersionTagSave {
	my $self = shift;
        return WebGUI::Privilege::insufficient() unless (WebGUI::Grouping::isInGroup(12));
	$self->addVersionTag($session{form}{name});
	return $self->www_manageVersions();
}


#-------------------------------------------------------------------A

sub www_commitVersionTag {
	my $self = shift;
	return WebGUI::Privilege::adminOnly() unless WebGUI::Grouping::isInGroup(3);
	my $tagId = $session{form}{tagId};
	if ($tagId) {
		$self->commitVersionTag($tagId);
	}
	return $self->www_manageVersions;
}

#-------------------------------------------------------------------

=head2 www_manageVersionTags ()

Shows a list of the currently available asset version tags.

=cut

sub www_manageCommittedVersions {
        my $self = shift;
        my $ac = WebGUI::AdminConsole->new("versions");
        return WebGUI::Privilege::insufficient() unless (WebGUI::Grouping::isInGroup(3));
        my $i18n = WebGUI::International->new("Asset");
	my $rollback = $i18n->get('rollback');
	my $rollbackPrompt = $i18n->get('rollback version tag confirm');
        $ac->addSubmenuItem($self->getUrl('func=addVersionTag'), $i18n->get("add a version tag"));
        $ac->addSubmenuItem($self->getUrl('func=manageVersions'), $i18n->get("manage versions"));
        my $output = '<table width=100% class="content">
        <tr><th>Tag Name</th><th>Committed On</th><th>Committed By</th><th></th></tr> ';
        my $sth = WebGUI::SQL->read("select tagId,name,commitDate,committedBy from assetVersionTag where isCommitted=1");
        while (my ($id,$name,$date,$by) = $sth->array) {
                my $u = WebGUI::User->new($by);
                $output .= '<tr><td>'.$name.'</td><td>'.WebGUI::DateTime::epochToHuman($date).'</td><td>'.$u->username.'</td><td><a href="'.$self->getUrl("func=rollbackVersionTag;tagId=".$id).'" onclick="return confirm(\''.$rollbackPrompt.'\');">'.$rollback.'</a></td></tr>';
        }
        $sth->finish;
        $output .= '</table>';
        return $ac->render($output,$i18n->get("committed versions"));
}


#-------------------------------------------------------------------

=head2 www_manageRevisions ()

Shows a list of the revisions for this asset.

=cut

sub www_manageRevisions {
        my $self = shift;
        my $ac = WebGUI::AdminConsole->new("versions");
        return WebGUI::Privilege::insufficient() unless (WebGUI::Grouping::isInGroup(3));
        my $i18n = WebGUI::International->new("Asset");
        #$ac->addSubmenuItem($self->getUrl('func=addVersionTag'), $i18n->get("add a version tag"));
        #$ac->addSubmenuItem($self->getUrl('func=manageVersions'), $i18n->get("manage versions"));
        my $output = '<table width=100% class="content">
        <tr><th></th><th>Revision Date</th><th>Revised By</th><th>Tag Name</th></tr> ';
        my $sth = WebGUI::SQL->read("select assetData.revisionDate, users.username, assetVersionTag.name from assetData 
		left join assetVersionTag on assetData.tagId=assetVersionTag.tagId left join users on assetData.revisedBy=users.userId
		where assetData.assetId=".quote($self->getId));
        while (my ($date,$by,$tag) = $sth->array) {
                $output .= '<tr><td>'.WebGUI::Icon::deleteIcon("func=rollbackAssetRevision",$self->get("url"),$i18n->get("purge revision prompt")).'</td><td>'.WebGUI::DateTime::epochToHuman($date).'</td><td>'.$by.'</td><td>'.$tag.'</td></tr>';
        }
        $sth->finish;
        $output .= '</table>';
        return $ac->render($output,$i18n->get("committed versions").": ".$self->getTitle);
}


#-------------------------------------------------------------------

=head2 www_manageVersionTags ()

Shows a list of the currently available asset version tags.

=cut

sub www_manageVersions {
	my $self = shift;
        my $ac = WebGUI::AdminConsole->new("versions");
        return WebGUI::Privilege::insufficient() unless (WebGUI::Grouping::isInGroup(12));
	my $i18n = WebGUI::International->new("Asset");
	$ac->setHelp("versions manage");
	my $i18n = WebGUI::International->new("Asset");
	$ac->addSubmenuItem($self->getUrl('func=addVersionTag'), $i18n->get("add a version tag"));
	$ac->addSubmenuItem($self->getUrl('func=manageCommittedVersions'), $i18n->get("manage committed versions"));
	my ($tag) = WebGUI::SQL->quickArray("select name from assetVersionTag where tagId=".quote($session{scratch}{versionTag}));
	$tag ||= "None";
	my $rollback = $i18n->get("rollback");
	my $commit = $i18n->get("commit");
	my $rollbackPrompt = $i18n->get("rollback version tag confirm");
	my $commitPrompt = $i18n->get("commit version tag confirm");
	my $output = '<p>You are currently working under a tag called: <b>'.$tag.'</b>.</p><table width=100% class="content">
	<tr><th>Tag Name</th><th>Created On</th><th>Created By</th><th></th></tr> ';
	my $sth = WebGUI::SQL->read("select tagId,name,creationDate,createdBy from assetVersionTag where isCommitted=0");
	while (my ($id,$name,$date,$by) = $sth->array) {
		my $u = WebGUI::User->new($by);
		$output .= '<tr><td><a href="'.$self->getUrl("func=setVersionTag;tagId=".$id).'">'.$name.'</a></td>
			<td>'.WebGUI::DateTime::epochToHuman($date).'</td>
			<td>'.$u->username.'</td>
			<td><a href="'.$self->getUrl("func=rollbackVersionTag;tagId=".$id).'" onclick="return confirm(\''.$rollbackPrompt.'\');">'.$rollback.'</a> |
			<a href="'.$self->getUrl("func=commitVersionTag;tagId=".$id).'" onclick="return confirm(\''.$commitPrompt.'\');">'.$commit.'</a></td></tr>';
	}
	$sth->finish;	
	$output .= '</table>';
	return $ac->render($output);
}


#-------------------------------------------------------------------A

sub www_purgeAssetRevision {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	my $revisionDate = $session{form}{revisionDate};
	return undef unless $revisionDate;
	WebGUI::Asset->new($self->getId,$self->get("className"),$revisionDate)->purgeRevision;
	return $self->www_manageRevisions;
}


#-------------------------------------------------------------------A

sub www_rollbackVersionTag {
	my $self = shift;
	return WebGUI::Privilege::adminOnly() unless WebGUI::Grouping::isInGroup(3);
	my $tagId = $session{form}{tagId};
	if ($tagId) {
		$self->rollbackVersionTag($tagId);
	}
	return $self->www_manageVersions;
}

#-------------------------------------------------------------------A

sub www_rollbackSiteToTime {
	my $self = shift;
	return WebGUI::Privilege::adminOnly() unless WebGUI::Grouping::isInGroup(3);

}


#-------------------------------------------------------------------

=head2 www_setVersionTag ()

Sets the current user's working version tag.

=cut

sub www_setVersionTag () {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless WebGUI::Grouping::isInGroup(12);
	WebGUI::Session::setScratch("versionTag",$session{form}{tagId});
	return $self->www_manageVersions();
}


1;

