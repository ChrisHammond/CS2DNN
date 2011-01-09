/*
only do this after you've copied the forum/storage folders over into portals/#/forums/attachments 

then synchronize the file manager (set executiontimeout to 10000 or something large in web.config due to bug in filemanager timing out)

change source db currently [SOURCEDB]
change target db currently [TARGETDB]

*/

select 'exec forum_attachment_update null,', f.FileId, ',', ft.topicid, ',', fp.UserID, ',''', replace(f.FileName, '''',''''''), ''',', 0

from 

[TARGETDB].dbo.Files f
join [SOURCEDB].dbo.cs_PostAttachments cpa on (f.FileName = cpa.FileName)
join [TARGETDB].dbo.cs_forums_topics ft on (ft.postid = cpa.PostID)
join [TARGETDB].dbo.Forum_Posts fp on (fp.PostID = ft.topicid)


/* remove tabs before and after file name before executing
	replace any 's in file names with ''
	Color coding in query window works best to find 's
 */