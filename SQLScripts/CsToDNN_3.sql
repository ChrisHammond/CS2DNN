/* RUN THIS SCRIPT THIRD */
/* This script brings over all the Forum Thread Replies, it will take a while to run on a large site */

/* change source database name (currently SOURCEDB) */
/* change target database name (currently TARGETDB) */
/* change moduleid to the ID of the main forums module installed on your DNN site (currently MODULEID) */
/* change registered users role if necessary (currently 1) */
/* change portalid if necessary (currently 0) */

/* before executing change the results to file instead of grid */


SET NOCOUNT ON
use [SOURCEDB]

/* setup the portalid */
declare @portalid int 
set @portalid=0


declare @RowNum int
declare @RowMax int

set @RowNum = 0 

--get the number of rows 
select @RowMax = count(*) from cs_posts 
	where sectionid in 
		(select sectionid 
			from cs_sections cs 
			where 
				groupid in (select groupid from cs_groups where applicationtype=0))
	and postlevel>1
	

declare @oldpostid int
declare @newpostid int
declare @PostRowMax int
declare @PostRowNum int

select top 1 
	@oldpostid = postid 
from
	[TARGETDB].dbo.[cs_forums_topics]
where postlevel > 1
order by postid

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
	declare @replyid int	
	declare @replytoid int 
	declare @threadid int 


	select  top 1 	
 		@subject = cp.[Subject]
		, @body = cp.Body
		, @datecreated = cp.PostDate
		, @dateupdated = cp.PostDate
		, @authorid = (select top 1 newuserid from [TARGETDB].dbo.[conversion_users] where olduserid=cp.userid)
		, @authorname = cp.postauthor --get the author name
		, @ipaddress = cp.IpAddress
		, @forumid = (select top 1 forumid from [TARGETDB].dbo.[conversion_forums] where sectionid=cp.sectionid)
		, @viewcount = cp.TotalViews
--		, @topicid = (select top 1 topicid from [TARGETDB].dbo.cs_forums_topics cf where cf.postid = cp.threadid)
		, @topicid = (select top 1 cf.topicid from [TARGETDB].dbo.cs_forums_topics cf where cf.threadid = cp.threadid and postlevel=1)
		, @replytoid = (select top 1 topicid from [TARGETDB].dbo.cs_forums_topics cf where cf.postid = cp.parentid)
		, @threadid = cp.threadid
--select * from [TARGETDB].dbo.cs_forums_topics cf where postlevel=2
	
 	from
 		cs_posts cp
		
	where 
		cp.PostId = @oldpostid
	order by postId


--for each item we need to add loop through
while @RowNum < @RowMax
begin
	set @RowNum = @RowNum + 1

	--PRINT 'Insert New Reply' 
	exec @newtopicid = [TARGETDB].dbo.[Forum_Post_Add_Conversion] @TopicId, @ForumId, @authorid, @ipaddress, @subject, @body, 0, '1900-01-01 00:00:00.000',0,@PortalId,0,0,0, @datecreated, @dateupdated

			--PRINT 'parentid ' + str(@topicid) 
			--PRINT 'threadid ' + str(@threadid) 
			--PRINT 'replytoid ' + str(@replytoid) 
			--PRINT 'generated topic ' + str(@newtopicid) 
			
	update [TARGETDB].dbo.cs_forums_topics
	set topicid = @newtopicid
	where postid = @oldpostid
	
			--PRINT 'Old post id: ' + str(@oldpostid) + ' New topicid:' + str(@newtopicid)  + ' topicid:' + str(@topicid)
		select  top 1 	
			@oldpostid = cfm.postid
	 		, @subject = cp.[Subject]
			, @body = cp.Body
			, @datecreated = cp.PostDate
			, @dateupdated = cp.PostDate
			, @authorid = (select top 1 newuserid from [TARGETDB].dbo.[conversion_users] where olduserid=cp.userid)
			, @authorname = cp.postauthor --get the author name
			, @ipaddress = cp.IpAddress
			, @topicid = (select top 1 cf.topicid from [TARGETDB].dbo.cs_forums_topics cf where cf.threadid = cp.threadid)
			, @replytoid = (select top 1 topicid from [TARGETDB].dbo.cs_forums_topics cf where cf.postid = cp.parentid)
			, @threadid = cp.threadid
	 	from
	 		[TARGETDB].dbo.cs_forums_topics cfm
			join cs_posts cp on (cfm.postid= cp.postid)
		where 
			cfm.PostId > @oldpostid
			and cfm.postlevel >1
		order by cfm.postId

end

