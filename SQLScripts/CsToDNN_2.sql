/* RUN THIS SCRIPT SECOND */
/* This script brings over all the Forum Threads */

/* change source database name (currently SOURCEDB) */
/* change target database name (currently TARGETDB) */
/* change moduleid to the ID of the main forums module installed on your DNN site (currently MODULEID) */
/* change registered users role if necessary (currently 1) */
/* change portalid if necessary (currently 0) */

/* before executing change the results to file instead of grid */


 SET NOCOUNT ON

/* setup the portalid */
declare @portalid int 
set @portalid=0


use [SOURCEDB]

declare @RowNum int
declare @RowMax int

set @RowNum = 0 

--get the number of rows 
select @RowMax = count(*) from cs_posts 
	where sectionid in (select sectionid from cs_sections cs where groupid in (select groupid from cs_groups where applicationtype=0))
	and postlevel=1

--PRINT '--truncate cs_forums_topics'
truncate table [TARGETDB].dbo.[cs_forums_topics]

--PRINT '--update the cs_forums_topics table with old postids'
insert into [TARGETDB].dbo.[cs_forums_topics]
(threadid, postid, parentid, topicid, postlevel)
(select cp.threadid, cp.postid, cp.parentid, null, cp.postlevel from cs_posts cp where sectionid in 
	(select sectionid from cs_sections cs where groupid in (select groupid from cs_groups where applicationtype=0)))


declare @oldpostid int
declare @newpostid int
declare @PostRowMax int
declare @PostRowNum int

select top 1 
@oldpostid = postid 
from
 [TARGETDB].dbo.[cs_forums_topics]
where postlevel = 1

	declare @topicid int
	declare @newtopicid int
	declare @subject nvarchar(255)
	declare @body nvarchar(max)
	declare @datecreated datetime
	declare @dateupdated datetime
	declare @authorid int
	declare @authorname nvarchar(150)
	declare @ipaddress nvarchar(32)
	declare @forumid int
	declare @viewcount int

	select  top 1 	
 		@subject = cp.[Subject]
		, @body = cp.Body
		, @datecreated = cp.PostDate
		, @dateupdated = cp.PostDate
		, @authorid = (select newuserid from [TARGETDB].dbo.[conversion_users] where olduserid=cp.userid)
		, @authorname = cp.postauthor --get the author name
		, @ipaddress = cp.IpAddress
		, @forumid = (select forumid from [TARGETDB].dbo.[conversion_forums] cf where cf.sectionid=cp.sectionid)
		, @viewcount = cp.TotalViews
 	from
 		cs_posts cp
	where 
		cp.PostId = @oldpostid
	order by postId

--for each item we need to add loop through
while @RowNum < @RowMax
begin
	set @RowNum = @RowNum + 1

	set @topicid = -1
	
	--PRINT 'Insert New Topic' 
	exec @newtopicid = [TARGETDB].dbo.[Forum_Post_Add_Conversion] 0, @ForumId, @authorid, @ipaddress, @subject, @body, 0, '1900-01-01 00:00:00.000',0,@PortalId,0,0,0, @datecreated, @dateupdated
			

	update [TARGETDB].dbo.cs_forums_topics
	set topicid = @newtopicid
	where postid = @oldpostid

		--PRINT 'Old post id: ' + str(@oldpostid) + ' New topicid:' + str(@newtopicid)
	select  top 1 	
		@oldpostid = cfm.postid
 		, @subject = cp.[Subject]
		, @body = cp.Body
		, @datecreated = cp.PostDate
		, @dateupdated = cp.PostDate
		, @authorid = (select newuserid from [TARGETDB].dbo.[conversion_users] where olduserid=cp.userid)
		, @authorname = cp.postauthor --get the author name
		, @ipaddress = cp.IpAddress
		, @forumid = (select forumid from [TARGETDB].dbo.[conversion_forums] cf where cf.sectionid=cp.sectionid)
		, @viewcount = cp.TotalViews
 	from
 		[TARGETDB].dbo.cs_forums_topics cfm
		join cs_posts cp on (cfm.postid= cp.postid)
	where 
		cfm.PostId > @oldpostid
		and cfm.postlevel = 1
	order by cfm.postId
end

