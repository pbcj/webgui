insert into webguiVersion values ('4.6.7','upgrade',unix_timestamp());
alter table international add column lastUpdated int;
update international set lastUpdated=1031514049 where languageId=1;
update international set lastUpdated=1031516049 where languageId<>1;
delete from international where languageId=1 and namespace='WebGUI' and internationalId=722;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (722,1,'WebGUI','Id', 1031517195);
delete from international where languageId=1 and namespace='UserSubmission' and internationalId=61;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (61,1,'UserSubmission','User Submission System, Add/Edit', 1031517089);
delete from international where languageId=1 and namespace='UserSubmission' and internationalId=71;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (71,1,'UserSubmission','User Submission Systems are a great way to add a sense of community to any site as well as get free content from your users.\r\n<br><br>\r\n\r\n<b>Layout</b><br>\r\nWhat should this user submission system look like? Currently these are the views available:\r\n<ul>\r\n<li><b>Traditional</b> - Creates a simple spreadsheet style table that lists off each submission and is sorted by date. \r\n</li>\r\n<li><b>Web Log</b> - Creates a view that looks like the news site <a href="http://slashdot.org/">Slashdot</a>. Incidentally, Slashdot invented the web log format, which has since become very popular on news oriented sites. To limit the amount of the article shown on the main page, place the separator macro ^-; where you\'d like the front page content to stop.\r\n</li>\r\n<li><b>Photo Gallery</b> - Creates a matrix of thumbnails that can be clicked on to view the full image.\r\n</li></ul>\r\n\r\n<b>Who can approve?</b><br>\r\nWhat group is allowed to approve and deny content?\r\n<br><br>\r\n\r\n<b>Who can contribute?</b><br>\r\nWhat group is allowed to contribute content?\r\n<br><br>\r\n\r\n<b>Submissions Per Page</b><br>\r\nHow many submissions should be listed per page in the submissions index?\r\n<br><br>\r\n\r\n<b>Default Status</b><br>\r\nShould submissions be set to <i>Approved</i>, <i>Pending</i>, or <i>Denied</i> by default?\r\n<br><br>\r\n<i>Note:</i> If you set the default status to Pending, then be prepared to monitor your message log for new submissions.\r\n<p>\r\n\r\n<b>Karma Per Submission</b><br>\r\nHow much karma should be given to a user when they contribute to this user submission system?\r\n<p>\r\n\r\n\r\n<b>Display thumbnails?</b><br>\r\nIf there is an image present in the submission, the thumbnail will be displayed in the Layout (see above).\r\n<p>\r\n\r\n<b>Allow discussion?</b><br>\r\nDo you wish to attach a discussion to this user submission system? If you do, users will be able to comment on each submission.\r\n<p>\r\n\r\n<b>Who can post?</b><br>\r\nSelect the group that is allowed to post to this discussion.\r\n<p>\r\n\r\n<b>Edit Timeout</b><br>\r\nHow long should a user be able to edit their post before editing is locked to them?\r\n<p>\r\n<i>Note:</i> Don\'t set this limit too high. One of the great things about discussions is that they are an accurate record of who said what. If you allow editing for a long time, then a user has a chance to go back and change his/her mind a long time after the original statement was made.\r\n<p>\r\n\r\n<b>Karma Per Post</b><br>\r\nHow much karma should be given to a user when they post to this discussion?\r\n<p>\r\n\r\n<b>Who can moderate?</b><br>\r\nSelect the group that is allowed to moderate this discussion.\r\n<p>\r\n\r\n<b>Moderation Type?</b><br>\r\nYou can select what type of moderation you\'d like for your users. <i>After-the-fact</i> means that when a user posts a message it is displayed publically right away. <i>Pre-emptive</i> means that a moderator must preview and approve users posts before allowing them to be publically visible. Alerts for new posts will automatically show up in the moderator\'s WebGUI Inbox.\r\n<p>\r\nNote: In both types of moderation the moderator can always edit or delete the messages posted by your users.\r\n<p>\r\n', 1031517089);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=721;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (721,1,'WebGUI','Namespace', 1031515005);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=720;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (720,1,'WebGUI','OK', 1031514777);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=719;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (719,1,'WebGUI','Out of Date', 1031514679);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=588;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (588,1,'WebGUI','Are you certain you wish to submit this translation to Plain Black for inclusion in the official distribution of WebGUI? By clicking on the yes link you understand that you\'re giving Plain Black an unlimited license to use the translation in its software distributions.', 1031514630);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=594;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (594,1,'WebGUI','Translate messages.', 1031514314);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=593;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (593,1,'WebGUI','Submit translation.', 1031514223);
delete from international where languageId=1 and namespace='WebGUI' and internationalId=718;
insert into international (internationalId,languageId,namespace,message,lastUpdated) values (718,1,'WebGUI','Export translation.', 1031514184);






