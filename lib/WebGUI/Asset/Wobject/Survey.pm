package WebGUI::Asset::Wobject::Survey;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use WebGUI::DateTime;
use WebGUI::Grouping;
use WebGUI::HTMLForm;
use WebGUI::HTTP;
use WebGUI::Icon;
use WebGUI::Id;
use WebGUI::International;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::URL;
use WebGUI::Utility;
use WebGUI::Asset::Wobject;
use Digest::MD5 qw(md5_hex);

our @ISA = qw(WebGUI::Asset::Wobject);

#-------------------------------------------------------------------
sub addAnswer {
	$_[0]->setCollateral("Survey_answer","Survey_answerId",{
		Survey_id=>$_[0]->get("Survey_id"),
		Survey_questionId=>$_[2],
		Survey_answerId=>"new",
		answer=>WebGUI::International::get($_[1],'Survey')
		},1,0,"Survey_id");
}

#-------------------------------------------------------------------
sub completeResponse {
	my $self = shift;
	my $responseId = shift;
	WebGUI::SQL->setRow("Survey_response","Survey_responseId",{
		'Survey_responseId'=>$responseId,
		isComplete=>1
		});
	WebGUI::Session::deleteScratch($self->getResponseIdString);
}

#-------------------------------------------------------------------
sub definition {
        my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
		tableName	=> 'Survey',
		className	=> 'WebGUI::Asset::Wobject::Survey',
                properties	=> {
			templateId => {
				fieldType	=> 'template',
				deafultValue	=> 'PBtmpl0000000000000061'
				},
			Survey_id => {
				fieldType	=> 'text',
				defaultValue	=> undef
				}, 
			questionOrder => {
				fieldType	=> 'text',
				defaultValue	=> 'sequential'
				}, 
			groupToTakeSurvey => {
				fieldType	=> 'group',
				defaultValue	=> 2
				}, 
			groupToViewReports => {
				fieldType	=> 'group',
				defaultValue	=> 4
				},
			mode => {
				fieldType 	=> 'text',
				defaultValue	=> 'survey'
				},
			anonymous=>{
				fieldType	=> 'yesNo',
				defaultValue	=> 0
				},
			maxResponsesPerUser=>{
				fieldType	=> 'integer',
				defaultValue	=> 1
				},
			questionsPerResponse=>{
				fieldType	=> 'integer',
				defaultValue	=>99999
				},
			questionsPerPage=>{
				fieldType	=> 'integer',
				defaultValue	=> 1
				},
			overviewTemplateId=>{
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000063'
				},
			gradebookTemplateId => {
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000062'
				},
			responseTemplateId => {
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000064'
				},
			}
		});
	return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub duplicate {
	my ($self, $newAsset, $newSurveyId, $qdata, $adata, $rdata, $a, $b, $c);
	
	$self = shift;
	
	$newAsset = $self->SUPER::duplicate(shift);
	$newSurveyId = WebGUI::Id::generate();
	$newAsset->set({
		Survey_id=>$newSurveyId
		});
	$a = WebGUI::SQL->read("select * from Survey_question where Survey_id=".quote($self->get("Survey_id"))
		." order by sequenceNumber");
	while ($qdata = $a->hashRef) {
		$b = WebGUI::SQL->read("select * from Survey_answer where Survey_questionId=".quote($qdata->{Survey_questionId})
			." order by sequenceNumber");
		$qdata->{Survey_questionId} = "new";
		$qdata->{Survey_id} = $newSurveyId;
		$qdata->{Survey_questionId} = $newAsset->setCollateral("Survey_question","Survey_questionId",$qdata,1,0,"Survey_id");
		while ($adata = $b->hashRef) {
			$c = WebGUI::SQL->read("select * from Survey_response where Survey_answerId=".quote($adata->{Survey_answerId}));
			$adata->{Survey_answerId} = "new";
			$adata->{Survey_questionId} = $qdata->{Survey_questionId};
			$adata->{Survey_id} = $newSurveyId;
			$adata->{Survey_answerId} = $newAsset->setCollateral("Survey_answer", "Survey_answerId", $adata, 
				1, 0, "Survey_Id");
			while ($rdata = $c->hashRef) {
				$rdata->{Survey_responseId} = "new";
				$rdata->{Survey_answerId} = $adata->{Survey_answerId};
				$rdata->{Survey_id} = $newSurveyId;
				$rdata->{Survey_questionId} = $qdata->{Survey_questionId};
				$newAsset->setCollateral("Survey_response","Survey_responseId",$rdata,0,0);
			}
			$c->finish;
		}
		$b->finish;
	}
	$a->finish;
}

#-------------------------------------------------------------------
sub generateResponseId {
	my $self = shift;
	my $varname = $self->getResponseIdString;
	if ($session{scratch}{$varname}) {
		$self->completeResponse;
	}
	my $ipAddress = $self->getIp; 
	my $userId = $self->getUserId; 
	my $responseId = WebGUI::SQL->setRow("Survey_response","Survey_responseId",{
		'Survey_responseId'=>"new",
		userId=>$userId,
		ipAddress=>$ipAddress,
		username=>$session{user}{username},
		startDate=>WebGUI::DateTime::time(),
		'Survey_id'=>$self->get("Survey_id")
		});
	WebGUI::Session::setScratch($varname,$responseId);
	return $responseId;
}

#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm;

	$tabform->getTab('properties')->hidden("Survey_id",($self->get("Survey_id") || WebGUI::Id::generate()));
	$tabform->getTab('display')->template(
		-name		=> 'templateId',
		-label		=> WebGUI::International::get('view template', 'Survey'),
		-value		=> $self->getValue('templateId'),
		-namespace	=> 'Survey',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'responseTemplateId',
		-label		=> WebGUI::International::get('response template', 'Survey'),
		-value		=> $self->getValue('responseTemplateId'),
		-namespace	=> 'Survey/Response',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'gradebookTemplateId',
		-label		=> WebGUI::International::get('gradebook template', 'Survey'),
		-value		=> $self->getValue('gradebookTemplateId'),
		-namespace	=> 'Survey/Gradebook',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'overviewTemplateId',
		-label		=> WebGUI::International::get('overview template', 'Survey'),
		-value		=> $self->getValue('overviewTemplateId'),
		-namespace	=> 'Survey/Overview',
		-afterEdit	=> 'func=edit'
		);

	$tabform->getTab('display')->selectList(
		-name		=> "questionOrder",
		-options	=> {
			sequential => WebGUI::International::get(5,'Survey'),
                	random => WebGUI::International::get(6,'Survey'),
                	response => WebGUI::International::get(7,'Survey')
			},
		-label		=> WebGUI::International::get(8,'Survey'),
		-value		=> [$self->getValue("questionOrder")]
		);
	$tabform->getTab('display')->integer(
		-name		=> "questionsPerPage",
		-value		=> $self->getValue("questionsPerPage"),
		-label		=> WebGUI::International::get(83,'Survey')
		);
        $tabform->getTab('properties')->selectList(
                -name	=> "mode",
                -options	=> {
			survey => WebGUI::International::get(9,'Survey'),
                	quiz => WebGUI::International::get(10,'Survey')
			},
                -label		=> WebGUI::International::get(11,'Survey'),
                -value		=> [$self->getValue("mode")]
                );
	$tabform->getTab('properties')->yesNo(
		-name		=> "anonymous",
               	-value		=> $self->getValue("anonymous"),
               	-label		=> WebGUI::International::get(81,'Survey')
               	);
	$tabform->getTab('properties')->integer(
		-name		=> "maxResponsesPerUser",
		-value		=> $self->getValue("maxResponsesPerUser"),
		-label		=> WebGUI::International::get(84,'Survey')
		);
	$tabform->getTab('properties')->integer(
		-name		=> "questionsPerResponse",
		-value		=> $self->getValue("questionsPerResponse"),
		-label		=> WebGUI::International::get(85,'Survey')
		);	
	$tabform->getTab('security')->group(
		-name		=> "groupToTakeSurvey",
		-value		=> [$self->getValue("groupToTakeSurvey")],
		-label		=> WebGUI::International::get(12,'Survey')
		);
        $tabform->getTab('security')->group(
                -name		=> "groupToViewReports",
                -label		=> WebGUI::International::get(13,'Survey'),
                -value		=> [$self->getValue("groupToViewReports")]
                );
	if ($self->get("wobjectId") eq "new") {
		$tabform->getTab('properties')->whatNext(
			-options=>{
				addQuestion=>WebGUI::International::get(28,'Survey'),
				backToPage=>WebGUI::International::get(745)
				},
			-value=>"addQuestion"
			);
	}

	return $tabform;
}

#-------------------------------------------------------------------
sub getIcon {
	my $self = shift;
	my $small = shift;
	return $session{config}{extrasURL}.'/assets/small/survey.gif' if ($small);
	return $session{config}{extrasURL}.'/assets/survey.gif';
}

#
# WID FIXEN!
#
#-------------------------------------------------------------------
sub getIndexerParams {
	my $self = shift;        
	my $now = shift;
	return {
		Survey => {
                        sql =>"select Survey_question.question as question,
                                        Survey_question.Survey_questionId as Survey_questionId,
                                        asset.className as class,
                                        asset.ownerUserId as ownerId,
                                        asset.url as url,
                                        asset.assetId as assetId,
                                        asset.groupIdView as groupIdView,
                                        Survey.groupToTakeSurvey as special_groupIdView
                                        from Survey, asset
                                        left join Survey_question on Survey_question.Survey_id=Survey.Survey_id
                                        where Survey.assetId = asset.assetId
					and asset.startDate < $now
					and asset.endDate > $now",
                        fieldsToIndex => ["question",
                                          'select answer from Survey_answer where Survey_questionId = \'$data{Survey_questionId}\'' ],
                        contentType => 'content',
                        url => 'WebGUI::URL::gateway($data{url})',
                        headerShortcut => 'select title from asset where assetId = \'$data{assetId}\'',
                        bodyShortcut => '$textToIndex'
                }
	};
}


#-------------------------------------------------------------------
sub getIp {
	my $self = shift;
	my $ip = ($self->get("anonymous")) ? substr(md5_hex($session{env}{REMOTE_ADDR}),0,8) : $session{env}{REMOTE_ADDR};
	return $ip;
}



#-------------------------------------------------------------------
sub getMenuVars {
	my $self = shift;
	my %var;
	$var{'user.canViewReports'} = (WebGUI::Grouping::isInGroup($self->get("groupToViewReports")));
	$var{'delete.all.responses.url'} = $self->getUrl('func=deleteAllResponses');
	$var{'delete.all.responses.label'} = WebGUI::International::get(73,'Survey');
	$var{'export.answers.url'} = $self->getUrl('func=exportAnswers');
	$var{'export.answers.label'} = WebGUI::International::get(62,'Survey');
	$var{'export.questions.url'} = $self->getUrl('func=exportQuestions');
	$var{'export.questions.label'} = WebGUI::International::get(63,'Survey');
	$var{'export.responses.url'} = $self->getUrl('func=exportResponses');
	$var{'export.responses.label'} = WebGUI::International::get(64,'Survey');
	$var{'export.composite.url'} = $self->getUrl('func=exportComposite');
	$var{'export.composite.label'} = WebGUI::International::get(65,'Survey');
	$var{'report.gradebook.url'} = $self->getUrl('func=viewGradebook');
	$var{'report.gradebook.label'} = WebGUI::International::get(61,'Survey');
	$var{'report.overview.url'} = $self->getUrl('func=viewStatisticalOverview');
	$var{'report.overview.label'} = WebGUI::International::get(59,'Survey');
        $var{'survey.url'} = $self->getUrl;
	$var{'survey.label'} = WebGUI::International::get(60,'Survey');
	return \%var;
}

#-------------------------------------------------------------------
sub getQuestionCount {
	my $self = shift;
	my ($count) = WebGUI::SQL->quickArray("select count(*) from Survey_question where Survey_id=".quote($self->get("Survey_id")));
	return ($count < $self->getValue("questionsPerResponse")) ? $count : $self->getValue("questionsPerResponse");
}

#-------------------------------------------------------------------
sub getQuestionsLoop {
	my $self = shift;
	my $responseId = shift;
	my @ids;
	if ($self->get("questionOrder") eq "sequential") {
		@ids = $self->getSequentialQuestionIds($responseId);
	} elsif ($self->get("questionOrder") eq "response") {
		@ids = $self->getResponseDrivenQuestionIds($responseId);
	} else {
		@ids = $self->getRandomQuestionIds($responseId);
	}
	my $length = scalar(@ids);
	my $i = 1;
	my @loop;
	my $questionResponseCount = $self->getQuestionResponseCount($responseId);
	while ($i <= $length && $i<= $self->get("questionsPerPage") && ($questionResponseCount + $i) <= $self->getValue("questionsPerResponse")) {
		push(@loop,$self->getQuestionVars($ids[($i-1)]));
		$i++;
	}
	return \@loop;
}


#-------------------------------------------------------------------
sub getQuestionResponseCount {
	my $self = shift;
	my $responseId = shift;
	my ($count) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse where Survey_responseId=".quote($responseId));
	return $count;
}

#-------------------------------------------------------------------
sub getQuestionVars {
	my $self = shift;
	my $questionId = shift;
	my %var;
	my $question = WebGUI::SQL->getRow("Survey_question","Survey_questionId",$questionId);
	$var{'question.question'} = $question->{question};
	$var{'question.allowComment'} = $question->{allowComment};
	$var{'question.id'} = $question->{Survey_questionId};
	$var{'question.comment.field'} = WebGUI::Form::textarea({
		name=>'comment_'.$questionId
		});
	$var{'question.comment.label'} = WebGUI::International::get(51,'Survey');
	if ($question->{answerFieldType} eq "text") {
		my ($answer) = WebGUI::SQL->quickArray("select Survey_answerId from Survey_answer where Survey_questionId=".quote($question->{Survey_questionId})); 
		$var{'question.answer.field'} = WebGUI::Form::hidden({
			name=>'answerId_'.$questionId,
			value=>$answer
			});
		$var{'question.answer.field'} .= WebGUI::Form::text({
			name=>'textResponse_'.$questionId
			});
	} else {
		my $answer = WebGUI::SQL->buildHashRef("select Survey_answerId,answer from Survey_answer where Survey_questionId=".quote($question->{Survey_questionId})." order by sequenceNumber");
		if ($question->{randomizeAnswers}) {
			$answer = randomizeHash($answer);
		}
		$var{'question.answer.field'} = WebGUI::Form::radioList({
			options=>$answer,
			name=>"answerId_".$questionId,
			vertical=>1
			});
	}
	return \%var;
}

#-------------------------------------------------------------------
sub getRandomQuestionIds {
	my $self = shift;
	my $responseId = shift;
	my @usedQuestionIds = WebGUI::SQL->buildArray("select Survey_questionId from Survey_questionResponse where Survey_responseId=".quote($responseId));
	my $where = " where Survey_id=".quote($self->get("Survey_id"));
	if ($#usedQuestionIds+1 > 0) {
		$where .= " and Survey_questionId not in (".quoteAndJoin(\@usedQuestionIds).")";
	}
	my @questions = WebGUI::SQL->buildArray("select Survey_questionId from Survey_question".$where);
	randomizeArray(\@questions);
	return @questions;
}

#-------------------------------------------------------------------
sub getResponseCount {
	my $self = shift;
	my $ipAddress = $self->getIp;
	my $userId = $self->getUserId;
	my ($count) = WebGUI::SQL->quickArray("select count(*) from Survey_response where Survey_id=".quote($self->get("Survey_id"))." and 
		((userId<>'1' and userId=".quote($userId).") or ( userId='1' and ipAddress=".quote($ipAddress)."))");
	return $count;
}


#-------------------------------------------------------------------
sub getResponseDrivenQuestionIds {
	my $self = shift;
	my $responseId = shift;
        my $previousResponse = WebGUI::SQL->quickHashRef("select Survey_questionId, Survey_answerId from Survey_questionResponse 
		where Survey_responseId=".quote($responseId)." order by dateOfResponse desc");
	my $questionId;
	my @questions;
	if ($previousResponse->{Survey_answerId}) {
	        ($questionId) = WebGUI::SQL->quickArray("select gotoQuestion from Survey_answer where 
			Survey_answerId=".quote($previousResponse->{Survey_answerId}));
	        unless ($questionId) { 
			($questionId) = WebGUI::SQL->quickArray("select gotoQuestion from Survey_question where 
				Survey_questionId=".quote($previousResponse->{Survey_questionId}));
		}
		unless ($questionId) { # terminate survey
			$self->completeResponse($responseId);	
			return ();
		}
	} else {
		($questionId) = WebGUI::SQL->quickArray("select Survey_questionId from Survey_question where Survey_id=".quote($self->getValue("Survey_id"))."
			order by sequenceNumber");
	}
	push(@questions,$questionId);
	return @questions;
}

#-------------------------------------------------------------------
sub getResponseId {
	my $self = shift;
	return $session{scratch}{$self->getResponseIdString};
}

#-------------------------------------------------------------------
sub getResponseIdString {
	my $self = shift;
	return "Survey-".$self->get("Survey_id")."-ResponseId";
}


#-------------------------------------------------------------------
sub getSequentialQuestionIds {
	my $self = shift;
	my $responseId = shift;
	my @usedQuestionIds = WebGUI::SQL->buildArray("select Survey_questionId from Survey_questionResponse where Survey_responseId=".quote($responseId));
	my $where = " where Survey_id=".quote($self->get("Survey_id"));
	if ($#usedQuestionIds+1 > 0) {
		$where .= " and Survey_questionId not in (".quoteAndJoin(\@usedQuestionIds).")";
	}
	my @questions = WebGUI::SQL->buildArray("select Survey_questionId from Survey_question $where order by sequenceNumber");
	return @questions;
}

#-------------------------------------------------------------------
sub getUserId {
	my $self = shift;
	my $userId = ($self->get("anonymous") && $session{user}{userId} != 1) ? substr(md5_hex($session{user}{userId}),0,8) : $session{user}{userId};
	return $userId;
}

#-------------------------------------------------------------------
sub getName {
        return WebGUI::International::get(1,'Survey');
}

#-------------------------------------------------------------------
sub purge {
	my ($count) = WebGUI::SQL->quickArray("select count(*) from Survey where Survey_id=".quote($_[0]->get("Survey_id")));
	if ($count < 2) { ### Check for other wobjects using this survey.
        	WebGUI::SQL->write("delete from Survey_question where Survey_id=".quote($_[0]->get("Survey_id")));
        	WebGUI::SQL->write("delete from Survey_answer where Survey_id=".quote($_[0]->get("Survey_id")));
        	WebGUI::SQL->write("delete from Survey_response where Survey_id=".quote($_[0]->get("Survey_id")));
	}
        $_[0]->SUPER::purge();
}


#-------------------------------------------------------------------
sub responseIsComplete {
	my $self = shift;
	my $responseId = shift;
	my $response = WebGUI::SQL->getRow("Survey_response","Survey_responseId",$responseId);
	return $response->{isComplete};
}


#-------------------------------------------------------------------
sub setAnswerType {
	$_[0]->setCollateral("Survey_question","Survey_questionId",{
		Survey_questionId=>$_[2],
		Survey_id=>$_[0]->get("Survey_id"),
		answerFieldType=>$_[1]
		},1,0,"Survey_id");
}

#-------------------------------------------------------------------
sub getUiLevel {
	return 5;
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	$self->logView() if ($session{setting}{passiveProfilingEnabled});
	my $var = $self->getMenuVars;
	$var->{'question.add.url'} = $self->getUrl('func=editQuestion&qid=new');
	$var->{'question.add.label'} = WebGUI::International::get(30,'Survey');
	my @edit;
	my $sth = WebGUI::SQL->read("select Survey_questionId,question from Survey_question where Survey_id=".quote($self->get("Survey_id"))." order by sequenceNumber");
	while (my %data = $sth->hash) {
		push(@edit,{
			'question.edit.controls'=>
				deleteIcon('func=deleteQuestionConfirm&qid='.$data{Survey_questionId}, $self->getUrl, WebGUI::International::get(44,'Survey')).
				editIcon('func=editQuestion&qid='.$data{Survey_questionId}, $self->getUrl).
				moveUpIcon('func=moveQuestionUp&qid='.$data{Survey_questionId}, $self->getUrl).
				moveDownIcon('func=moveQuestionDown&qid='.$data{Survey_questionId}, $self->getUrl),
			'question.edit.question'=>$data{question},
			'question.edit.id'=>$data{Survey_questionId}
			});
		$var->{'question.edit_loop'} = \@edit;
	}
	$sth->finish;
	$var->{'user.canTakeSurvey'} = WebGUI::Grouping::isInGroup($self->get("groupToTakeSurvey"));
	if ($var->{'user.canTakeSurvey'}) {
		$var->{'response.Id'} = $self->getResponseId();
		$var->{'response.Count'} = $self->getResponseCount;
		$var->{'user.isFirstResponse'} = ($var->{'response.Count'} == 0 && !(exists $var->{'response.id'}));
		$var->{'user.canRespondAgain'} = ($var->{'response.Count'} < $self->get("maxResponsesPerUser"));
		if (($var->{'user.isFirstResponse'}) || ($session{form}{startNew} && $var->{'user.canRespondAgain'})) {
			$var->{'response.Id'} = $self->generateResponseId;
		}
		if ($var->{'response.Id'}) {
			$var->{'questions.soFar.count'} = $self->getQuestionResponseCount($var->{'response.Id'});
			($var->{'questions.correct.count'}) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse a, Survey_answer b where a.Survey_responseId="
				.quote($var->{'response.Id'})." and a.Survey_answerId=b.Survey_answerId and b.isCorrect=1");
			if ($var->{'questions.soFar.count'} > 0) {
				$var->{'questions.correct.percent'} = round(($var->{'questions.correct.count'}/$var->{'questions.soFar.count'})*100)
			}
			$var->{'response.isComplete'} = $self->responseIsComplete($var->{'response.Id'});
			$var->{question_loop} = $self->getQuestionsLoop($var->{'response.Id'});
		}
	}
	$var->{'form.header'} = WebGUI::Form::formHeader({-action=>$self->getUrl})
		.WebGUI::Form::hidden({
			name=>'func',
			value=>'respond'
			});
	$var->{'form.footer'} = WebGUI::Form::formFooter();
	$var->{'form.submit'} = WebGUI::Form::submit({
			value=>WebGUI::International::get(50,'Survey')
			});
	$var->{'questions.sofar.label'} = WebGUI::International::get(86,'Survey');
	$var->{'start.newResponse.label'} = WebGUI::International::get(87,'Survey');
	$var->{'start.newResponse.url'} = $self->getUrl("func=view&startNew=1"); 
	$var->{'thanks.survey.label'} = WebGUI::International::get(46,'Survey');
	$var->{'thanks.quiz.label'} = WebGUI::International::get(47,'Survey');
	$var->{'questions.total'} = $self->getQuestionCount;
	$var->{'questions.correct.count.label'} = WebGUI::International::get(52,'Survey');
	$var->{'questions.correct.percent.label'} = WebGUI::International::get(54,'Survey');
	$var->{'mode.isSurvey'} = ($self->get("mode") eq "survey");
	$var->{'survey.noprivs.label'} = WebGUI::International::get(48,'Survey');
	$var->{'quiz.noprivs.label'} = WebGUI::International::get(49,'Survey');
	return $self->processTemplate($var, $self->getValue("templateId"));
}

#-------------------------------------------------------------------
sub www_deleteAnswerConfirm {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        my ($answerCount) = WebGUI::SQL->quickArray("select count(*) from Survey_answer where Survey_questionId=".quote($session{form}{qid}));
	return $_[0]->i18n("cannot delete the last answer") unless($answerCount);
        WebGUI::SQL->write("delete from Survey_questionResponse where Survey_answerId=".quote($session{form}{aid}));
        $_[0]->deleteCollateral("Survey_answer","Survey_answerId",$session{form}{aid});
        $_[0]->reorderCollateral("Survey_answer","Survey_answerId","Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_deleteQuestionConfirm {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	WebGUI::SQL->write("delete from Survey_answer where Survey_questionId=".quote($session{form}{qid}));
	WebGUI::SQL->write("delete from Survey_questionResponse where Survey_questionId=".quote($session{form}{qid}));
        $_[0]->deleteCollateral("Survey_question","Survey_questionId",$session{form}{qid});
        $_[0]->reorderCollateral("Survey_question","Survey_questionId","Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_deleteResponse {
	return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
        return $_[0]->confirm(WebGUI::International::get(72,'Survey'),
                $_[0]->getUrl('func=deleteResponseConfirm&responseId='.$session{form}{responseId}));
}

#-------------------------------------------------------------------
sub www_deleteResponseConfirm {
	return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
        WebGUI::SQL->write("delete from Survey_response where Survey_responseId=".quote($session{form}{responseId}));
        WebGUI::SQL->write("delete from Survey_questionResponse where Survey_responseId=".quote($session{form}{responseId}));
        return $_[0]->www_viewGradebook;
}

#-------------------------------------------------------------------
sub www_deleteAllResponses {
	return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
        return $_[0]->confirm(WebGUI::International::get(74,'Survey'),
                $_[0]->getUrl('func=deleteAllResponsesConfirm'));
}

#-------------------------------------------------------------------
sub www_deleteAllResponsesConfirm {
	return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
        WebGUI::SQL->write("delete from Survey_response where Survey_id=".quote($_[0]->get("Survey_id"))); 
        WebGUI::SQL->write("delete from Survey_questionResponse where Survey_id=".quote($_[0]->get("Survey_id"))); 
        return "";
}

#-------------------------------------------------------------------
sub www_edit {
        my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	$self->getAdminConsole->setHelp("survey add/edit");
	return $self->getAdminConsole->render($self->getEditForm->print,WebGUI::International::get(2,'Survey'));
}

#-------------------------------------------------------------------
sub www_editSave {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->SUPER::www_editSave(); 
	if ($session{form}{proceed} eq "addQuestion") {
		$session{form}{qid} = "new";
		return $_[0]->www_editQuestion;
	}
        return "";
}

#-------------------------------------------------------------------
sub www_editAnswer {
        my ($question, $f, $answer, $self);
	$self = shift;
	
        return WebGUI::Privilege::insufficient() unless ($self->canEdit);
        
	$answer = $self->getCollateral("Survey_answer","Survey_answerId",$session{form}{aid});
        $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
        $f->hidden("wid",$session{form}{wid});
        $f->hidden("func","editAnswerSave");
        $f->hidden("qid",$session{form}{qid});
        $f->hidden("aid",$answer->{Survey_answerId});
        $f->text(
                -name=>"answer",
                -value=>$answer->{answer},
                -label=>WebGUI::International::get(19,'Survey')
                );
	if ($self->get("mode") eq "quiz") {
        	$f->yesNo(
                	-name=>"isCorrect",
                	-value=>$answer->{isCorrect},
                	-label=>WebGUI::International::get(20,'Survey')
                	);
	} else {
		$f->hidden("isCorrect",0);
	}
	if ($self->get("questionOrder") eq "response") {
		$question = WebGUI::SQL->buildHashRef("select Survey_questionId,question 
			from Survey_question where Survey_id=".quote($self->get("Survey_id"))." order by sequenceNumber");
		$question = { ('-1' => WebGUI::International::get(82,'Survey'),%$question) };
		$f->select(
			-name=>"gotoQuestion",
			-options=>$question,
			-value=>[$answer->{gotoQuestion}],
			-label=>WebGUI::International::get(21,'Survey')
			);
	}
	if ($answer->{Survey_answerId} eq "new") {
                my %options;
                tie %options, 'Tie::IxHash';
                %options = (
                        "addAnswer"=>WebGUI::International::get(24,'Survey'),
                        "addQuestion"=>WebGUI::International::get(28,'Survey'),
                        "editQuestion"=>WebGUI::International::get(75,'Survey'),
                        "backToPage"=>WebGUI::International::get(745)
                        );
                $f->whatNext(
                        -options=>\%options,
                        -value=>"addAnswer"
                        );
        }
        $f->submit;

#	$self->getAdminConsole->setHelp("survey add/edit");
	return $self->getAdminConsole->render($f->print, WebGUI::International::get(18));

}

#-------------------------------------------------------------------
sub www_editAnswerSave {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        $_[0]->setCollateral("Survey_answer", "Survey_answerId", {
                Survey_answerId => $session{form}{aid},
                Survey_questionId => $session{form}{qid},
                answer => $session{form}{answer},
                isCorrect => $session{form}{isCorrect},
		Survey_id=>$_[0]->get("Survey_id"),
                gotoQuestion => $session{form}{gotoQuestion}
                },1,0,"Survey_Id");
	if ($session{form}{proceed} eq "addQuestion") {
                $session{form}{qid} = "new";
	} elsif ($session{form}{proceed} eq "addAnswer") {
		$session{form}{aid} = "new";
		return $_[0]->www_editAnswer();
	} elsif ($session{form}{proceed} eq "backToPage") {
		return "";
        }
        return $_[0]->www_editQuestion();
}

#-------------------------------------------------------------------
sub www_editQuestion {
	my ($f, $question, $answerFieldType, $sth, %data, $self);
	$self = shift;

	return WebGUI::Privilege::insufficient() unless ($self->canEdit);

	tie %data, 'Tie::CPHash';
	$question = $self->getCollateral("Survey_question","Survey_questionId",$session{form}{qid});
	$answerFieldType = $question->{answerFieldType} || "radioList";
	
	$f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
	$f->hidden("wid",$self->get("wobjectId"));
	$f->hidden("func","editQuestionSave");
	$f->hidden("qid",$question->{Survey_questionId});
	$f->hidden("answerFieldType",$answerFieldType);
	$f->HTMLArea(
		-name	=> "question",
		-value	=> $question->{question},
		-label	=> WebGUI::International::get(14,'Survey')
		);
	$f->yesNo(
		-name	=> "allowComment",
		-value	=> $question->{allowComment},
		-label	=> WebGUI::International::get(15,'Survey')
		);
	$f->yesNo(
		-name	=> "randomizeAnswers",
		-value	=> $question->{randomizeAnswers},
		-label	=> WebGUI::International::get(16,'Survey')
		);
	if ($self->get("questionOrder") eq "response") {
		my $ql = WebGUI::SQL->buildHashRef("select Survey_questionId,question 
			from Survey_question where Survey_id=".quote($self->get("Survey_id"))." order by sequenceNumber");
		$ql = { ('-1' => WebGUI::International::get(82,'Survey'),%$ql) };
		$f->select(
			-name	=> "gotoQuestion",
			-options=> $ql,
			-value	=> [$question->{gotoQuestion}],
			-label	=> WebGUI::International::get(21,'Survey')
			);
	}
	
	if ($question->{Survey_questionId} eq "new") {
		my %options;
		tie %options, 'Tie::IxHash';
		%options = (
			"addMultipleChoiceAnswer"	=> WebGUI::International::get(24,'Survey'),
                        "addTextAnswer"			=> WebGUI::International::get(29,'Survey'),
                        "addBooleanAnswer"		=> WebGUI::International::get(25,'Survey'),
                        "addFrequencyAnswer"		=> WebGUI::International::get(26,'Survey'),
                        "addOpinionAnswer"		=> WebGUI::International::get(27,'Survey'),
			#"addQuestion"			=> WebGUI::International::get(28,'Survey'),
                        "backToPage"			=> WebGUI::International::get(745)
			);
        	$f->whatNext(
                	-options=> \%options,
                	-value	=> "addMultipleChoiceAnswer"
                	);
	}
	$f->submit;
	my $output = $f->print;
	if ($question->{Survey_questionId} ne "new" && $question->{answerFieldType} ne "text") {
		$output .= '<a href="'.$self->getUrl('func=editAnswer&aid=new&qid='
			.$question->{Survey_questionId}).'">'.WebGUI::International::get(23,'Survey').'</a><p>';
		$sth = WebGUI::SQL->read("select Survey_answerId,answer from Survey_answer 
			where Survey_questionId=".quote($question->{Survey_questionId})." order by sequenceNumber");
		while (%data = $sth->hash) {
			$output .= 
				deleteIcon('func=deleteAnswerConfirm&qid='.$question->{Survey_questionId}.'&aid='.$data{Survey_answerId}, 
					$self->getUrl,WebGUI::International::get(45)).
                                editIcon('func=editAnswer&qid='.$question->{Survey_questionId}.'&aid='.$data{Survey_answerId}, $self->getUrl).
                                moveUpIcon('func=moveAnswerUp'.'&qid='.$question->{Survey_questionId}.'&aid='.$data{Survey_answerId}, $self->getUrl).
                                moveDownIcon('func=moveAnswerDown&qid='.$question->{Survey_questionId}.'&aid='.$data{Survey_answerId}, $self->getUrl).
                                ' '.$data{answer}.'<br>';
		}
		$sth->finish;
	}

#	$self->getAdminConsole->setHelp("survey add/edit");
	return $self->getAdminConsole->render($f->print, WebGUI::International::get(17));

}

#-------------------------------------------------------------------
sub www_editQuestionSave {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$session{form}{qid} = $_[0]->setCollateral("Survey_question", "Survey_questionId", {
                question=>$session{form}{question},
        	Survey_questionId=>$session{form}{qid},
		Survey_id=>$_[0]->get("Survey_id"),
                allowComment=>$session{form}{allowComment},
		gotoQuestion=>$session{form}{gotoQuestion},
		answerFieldType=>$session{form}{answerFieldType},
                randomizeAnswers=>$session{form}{randomizeAnswers}
                },1,0,"Survey_id");
        if ($session{form}{proceed} eq "addMultipleChoiceAnswer") {
        	$session{form}{aid} = "new";
                return $_[0]->www_editAnswer();
	} elsif ($session{form}{proceed} eq "addTextAnswer") {
                $_[0]->setAnswerType("text",$session{form}{qid});
        	$_[0]->addAnswer(0,$session{form}{qid});
	} elsif ($session{form}{proceed} eq "addBooleanAnswer") {
        	$_[0]->addAnswer(31,$session{form}{qid});
        	$_[0]->addAnswer(32,$session{form}{qid});
	} elsif ($session{form}{proceed} eq "addOpinionAnswer") {
                $_[0]->addAnswer(33,$session{form}{qid});
                $_[0]->addAnswer(34,$session{form}{qid});
                $_[0]->addAnswer(35,$session{form}{qid});
                $_[0]->addAnswer(36,$session{form}{qid});
                $_[0]->addAnswer(37,$session{form}{qid});
                $_[0]->addAnswer(38,$session{form}{qid});
                $_[0]->addAnswer(39,$session{form}{qid});
	} elsif ($session{form}{proceed} eq "addFrequencyAnswer") {
                $_[0]->addAnswer(40,$session{form}{qid});
                $_[0]->addAnswer(41,$session{form}{qid});
                $_[0]->addAnswer(42,$session{form}{qid});
                $_[0]->addAnswer(43,$session{form}{qid});
                $_[0]->addAnswer(39,$session{form}{qid});
	} elsif ($session{form}{proceed} eq "addQuestion") {
		$session{form}{qid} eq "new";
                return $_[0]->www_editQuestion();
	}
        return "";
}

#-------------------------------------------------------------------
sub www_exportAnswers {
        return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename(WebGUI::URL::escape($_[0]->get("title")."_answers.tab"),"text/tab");
        return WebGUI::SQL->quickTab("select * from Survey_answer where Survey_id=".quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_exportComposite {
	return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename(WebGUI::URL::escape($_[0]->get("title")."_composite.tab"),"text/tab");
	return WebGUI::SQL->quickTab("select b.question, c.response, a.userId, a.username, a.ipAddress, c.comment, c.dateOfResponse from Survey_response a 
		left join Survey_questionResponse c on a.Survey_responseId=c.Survey_responseId 
		left join Survey_question b on c.Survey_questionId=b.Survey_questionId 
		where a.Survey_id=".quote($_[0]->get("Survey_id"))." order by a.userId, a.ipAddress, b.sequenceNumber");
}

#-------------------------------------------------------------------
sub www_exportQuestions {
        return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename(WebGUI::URL::escape($_[0]->get("title")."_questions.tab"),"text/tab");
        return WebGUI::SQL->quickTab("select * from Survey_question where Survey_id=".quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_exportResponses {
        return "" unless (WebGUI::Grouping::isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename(WebGUI::URL::escape($_[0]->get("title")."_responses.tab"),"text/tab");
        return WebGUI::SQL->quickTab("select * from Survey_response where Survey_id=".quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_moveAnswerDown {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralDown("Survey_answer","Survey_answerId",$session{form}{aid},"Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_moveAnswerUp {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralUp("Survey_answer","Survey_answerId",$session{form}{aid},"Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_moveQuestionDown {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralDown("Survey_question","Survey_questionId",$session{form}{qid},"Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_moveQuestionUp {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralUp("Survey_question","Survey_questionId",$session{form}{qid},"Survey_id");
        return ""; 
}

#-------------------------------------------------------------------
sub www_respond {
	my $self = shift;
	return "" unless (WebGUI::Grouping::isInGroup($self->get("groupToTakeSurvey")));
	my $varname = $self->getResponseIdString;
	return "" unless ($session{scratch}{$varname});
	my $userId = ($self->get("anonymous")) ? substr(md5_hex($session{user}{userId}),0,8) : $session{user}{userId};
	foreach my $key (keys %{$session{form}}) {
		if ($key =~ /^answerId_(.+)$/) {
			my $id = $1;
			my ($previousResponse) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse
				where Survey_answerId=".quote($session{form}{"answerId_".$id})." and Survey_responseId=".quote($session{scratch}{$varname}));
			next if ($previousResponse);
			my $answer = $self->getCollateral("Survey_answer","Survey_answerId",$session{form}{"answerId_".$id});
			my $response = $session{form}{"textResponse_".$id} || $answer->{answer};
			WebGUI::SQL->write("insert into Survey_questionResponse (Survey_answerId,Survey_questionId,Survey_responseId,Survey_id,comment,response,dateOfResponse) values (
				".quote($answer->{Survey_answerId}).", ".quote($answer->{Survey_questionId}).", ".quote($session{scratch}{$varname}).", ".quote($answer->{Survey_id}).",
				".quote($session{form}{"comment_".$id}).", ".quote($response).", ".WebGUI::DateTime::time().")");
		}
	}
	my $responseCount = $self->getQuestionResponseCount($session{scratch}{$varname}); 
	if ($responseCount >= $self->getValue("questionsPerResponse") || $responseCount >= $self->getQuestionCount) {
		WebGUI::SQL->setRow("Survey_response","Survey_responseId",{
			isComplete=>1,
			endDate=>WebGUI::DateTime::time(),
			Survey_responseId=>$session{scratch}{$varname}
			});
	}
	$self->logView() if ($session{setting}{passiveProfilingEnabled});
	return "";
}


#-------------------------------------------------------------------
sub www_viewGradebook {
	my $self = shift;
        return "" unless (WebGUI::Grouping::isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($session{setting}{passiveProfilingEnabled});
	my $var = $self->getMenuVars;
	$var->{title} = WebGUI::International::get(71,'Survey');
	my $p = WebGUI::Paginator->new($self->getUrl('func=viewGradebook'));
	$p->setDataByQuery("select userId,username,ipAddress,Survey_responseId,startDate,endDate from Survey_response 
		where isComplete=1 and Survey_id=".quote($self->get("Survey_id"))." order by username,ipAddress,startDate");
	my $users = $p->getPageData;
	($var->{'question.count'}) = WebGUI::SQL->quickArray("select count(*) from Survey_question where Survey_id=".quote($self->get("Survey_id")));
	if ($var->{'question.count'} > $self->get("questionsPerResponse")) {
		$var->{'question.count'} = $self->get("questionsPerResponse");
	}
	$var->{'response.user.label'} = WebGUI::International::get(67,'Survey');
	$var->{'response.count.label'} = WebGUI::International::get(52,'Survey');
	$var->{'response.percent.label'} = WebGUI::International::get(54,'Survey');
	my @responseloop;
	foreach my $user (@$users) {
		my ($correctCount) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse a left join
                	Survey_answer b on a.Survey_answerId=b.Survey_answerId where a.Survey_responseId=".quote($user->{Survey_responseId})
			." and b.isCorrect=1");
		push(@responseloop, {
			'response.url'=>$self->getUrl('func=viewIndividualSurvey&responseId='.$user->{Survey_responseId}),
			'response.user.name'=>($user->{userId} eq '1') ? $user->{ipAddress} : $user->{username},
			'response.count.correct' => $correctCount,
			'response.percent' => round(($correctCount/$var->{'question.count'})*100)
			});
	}
	$var->{response_loop} = \@responseloop;
	$p->appendTemplateVars($var);
	return $self->processTemplate($var,$self->getValue("gradebookTemplateId"));
#	return $self->processTemplate($self->getValue("gradebookTemplateId"),$var,"Survey/Gradebook");
}


#-------------------------------------------------------------------
sub www_viewIndividualSurvey {
	my $self = shift;
        return "" unless (WebGUI::Grouping::isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($session{setting}{passiveProfilingEnabled});
	my $var = $self->getMenuVars;
	$var->{'title'} = WebGUI::International::get(70,'Survey');
	$var->{'delete.url'} = $self->getUrl('func=deleteResponse&responseId='.$session{form}{responseId});
	$var->{'delete.label'} = WebGUI::International::get(69,'Survey');
	my $response = WebGUI::SQL->getRow("Survey_response","Survey_responseId",$session{form}{responseId});
	$var->{'start.date.label'} = WebGUI::International::get(76,'Survey');
	$var->{'start.date.epoch'} = $response->{startDate};
	$var->{'start.date.human'} = epochToHuman($response->{startDate},"%z");
	$var->{'start.time.human'} = epochToHuman($response->{startDate},"%Z");
	$var->{'end.date.label'} = WebGUI::International::get(77,'Survey');
	$var->{'end.date.epoch'} = $response->{endDate};
	$var->{'end.date.human'} = epochToHuman($response->{endDate},"%z");
	$var->{'end.time.human'} = epochToHuman($response->{endDate},"%Z");
	$var->{'duration.label'} = WebGUI::International::get(78,'Survey');
	$var->{'duration.minutes'} = int(($response->{end} - $response->{start})/60);
	$var->{'duration.minutes.label'} = WebGUI::International::get(79,'Survey');
	$var->{'duration.seconds'} = (($response->{endDate} - $response->{start})%60);
	$var->{'duration.seconds.label'} = WebGUI::International::get(80,'Survey');
	$var->{'answer.label'} = WebGUI::International::get(19,'Survey');
	$var->{'response.label'} = WebGUI::International::get(66,'Survey');
	$var->{'comment.label'} = WebGUI::International::get(57,'Survey');
	my $a = WebGUI::SQL->read("select Survey_questionId,question,answerFieldType from Survey_question 
		where Survey_id=".quote($self->get("Survey_id"))." order by sequenceNumber");
	my @questionloop;
	while (my $qdata = $a->hashRef) {
		my @aid;
		my @answer;
		if ($qdata->{answerFieldType} eq "radioList") {
			my $sth = WebGUI::SQL->read("select Survey_answerId,answer from Survey_answer 
				where Survey_questionId=".quote($qdata->{Survey_questionId})." and isCorrect=1 order by sequenceNumber");
			while (my $adata = $sth->hashRef) {
				push(@aid,$adata->{Survey_answerId});
				push(@answer,$adata->{answer});
			}
			$sth->finish;
		}
		my $rdata = WebGUI::SQL->quickHashRef("select Survey_answerId,response,comment from Survey_questionResponse 
			where Survey_questionId=".quote($qdata->{Survey_questionId})." and Survey_responseId=".quote($session{form}{responseId}));
		push(@questionloop,{
			question => $qdata->{question},
			'question.id'=>$qdata->{Survey_questionId},
			'question.isRadioList' => ($qdata->{answerFieldType} eq "radioList"),
			'question.response' => $rdata->{response},
			'question.comment' => $rdata->{comment},
			'question.isCorrect' => isIn($rdata->{Survey_answerId}, @aid),
			'question.answer' => join(", ",@answer),
			});
	}
	$a->finish;
	$var->{question_loop} = \@questionloop;
	return $self->processTemplate($var, $self->getValue("responseTemplateId"));
#	return $self->processTemplate($self->getValue("responseTemplateId"),$var,"Survey/Response");
}

#-------------------------------------------------------------------
sub www_viewStatisticalOverview {
	my $self = shift;
        return "" unless (WebGUI::Grouping::isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($session{setting}{passiveProfilingEnabled});
	my $var = $self->getMenuVars;
	$var->{title} = WebGUI::International::get(58,'Survey');
	my $p = WebGUI::Paginator->new($self->getUrl('func=viewStatisticalOverview'));
	$p->setDataByQuery("select Survey_questionId,question,answerFieldType,allowComment from Survey_question 
		where Survey_id=".quote($self->get("Survey_id"))." order by sequenceNumber");
	my $questions = $p->getPageData;
	my @questionloop;
	$var->{'answer.label'} = WebGUI::International::get(19,'Survey');
	$var->{'response.count.label'} = WebGUI::International::get(53,'Survey');
	$var->{'response.percent.label'} = WebGUI::International::get(54,'Survey');
	$var->{'show.responses.label'} = WebGUI::International::get(55,'Survey');
	$var->{'show.comments.label'} = WebGUI::International::get(56,'Survey');
	foreach my $question (@$questions) {
		my @answerloop;
		my ($totalResponses) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse where Survey_questionId=".quote($question->{Survey_questionId}));
		if ($question->{answerFieldType} eq "radioList") {
			my $sth = WebGUI::SQL->read("select Survey_answerId,answer,isCorrect from Survey_answer where
				Survey_questionId=".quote($question->{Survey_questionId})." order by sequenceNumber");
			while (my $answer = $sth->hashRef) {
				my ($numResponses) = WebGUI::SQL->quickArray("select count(*) from Survey_questionResponse where Survey_answerId=".quote($answer->{Survey_answerId}));
				my $responsePercent;
				if ($totalResponses) {
					$responsePercent = round(($numResponses/$totalResponses)*100);
				} else {
					$responsePercent = 0;
				}
				my @commentloop;
				my $sth2 = WebGUI::SQL->read("select comment from Survey_questionResponse where Survey_answerId=".quote($answer->{Survey_answerId}));
				while (my ($comment) = $sth2->array) {
					push(@commentloop,{
						'answer.comment'=>$comment
						});
				}
				$sth2->finish;
				push(@answerloop,{
					'answer.isCorrect'=>$answer->{isCorrect},
					'answer' => $answer->{answer},
					'answer.response.count' =>$numResponses,
					'answer.response.percent' =>$responsePercent,
					'comment_loop'=>\@commentloop
					});
			}
			$sth->finish;
		} else {
			my $sth = WebGUI::SQL->read("select response,comment from Survey_questionResponse where Survey_questionId=".quote($question->{Survey_questionId}));
			while (my $response = $sth->hashRef) {
				push(@answerloop,{
					'answer.response'=>$response->{response},
					'answer.comment'=>$response->{comment}
					});
			}
			$sth->finish;
		}
		push(@questionloop,{
			question=>$question->{question},
			'question.id'=>$question->{Survey_questionId},
			'question.isRadioList' => ($question->{answerFieldType} eq "radioList"),
			'question.response.total' => $totalResponses,
			'answer_loop'=>\@answerloop,
			'question.allowComment'=>$question->{allowComment}
			});
	}
	$var->{question_loop} = \@questionloop;
	$p->appendTemplateVars($var);

	return $self->processTemplate($var, $self->getValue("overviewTemplateId"));
#	return $self->processTemplate($self->getValue("overviewTemplateId"),$var,"Survey/Overview");
}

1;

