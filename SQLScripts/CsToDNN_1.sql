/* RUN THIS SCRIPT FIRST */
/* This script renames the Admin account to Admin2, resets the passwords for existing DNN users to clear text "dnnpassword" */
/* It then imports all the users from CommunityServer, All the Forum Groups and Forums, then the adds a stored procedure used in the other scripts */

/* the following steps should use a find/replace on all of the included SQL scripts */
/* change source database name (currently SOURCEDB) */
/* change target database name (currently TARGETDB) */
/* change forumMODULEID to the ID of the main forums module installed on your DNN site (currently forumMODULEID) */
/* change registered users role if necessary (currently 1) */
/* change portalid if necessary (currently 0) */
/* change admin@change.me to a valid email address for your website, this is the email address used for forum notifications */
/* change WEBSITENAME to the name of your website, it will be the name email notifications come from for the forums */
/* before executing change the results to file instead of grid */

SET NOCOUNT ON

use [TARGETDB]

update users
set username = 'admin2'
where username='admin'
GO

SET NOCOUNT ON

use [TARGETDB]

update aspnet_users
set username = 'admin2', loweredusername = 'admin2'
where username='admin'
GO
SET NOCOUNT ON
/* UPDATE existing ACCOUNTs CHECK FOR THE PROPER USER GUID */
update [TARGETDB].dbo.aspnet_membership 
set passwordsalt=''

--where userid='67721A61-DB0F-4CFE-82C4-56D1FF274C5D'

update [TARGETDB].dbo.aspnet_membership 
set password='dnnpassword'

--where userid='67721A61-DB0F-4CFE-82C4-56D1FF274C5D'

update [TARGETDB].dbo.aspnet_membership 
set passwordformat=0

--where userid='67721A61-DB0F-4CFE-82C4-56D1FF274C5D'


SET NOCOUNT ON

use [TARGETDB]
if exists (select * from dbo.sysobjects where id = object_id(N'[TARGETDB].[dbo].[conversion_users]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
DROP TABLE [TARGETDB].[dbo].[conversion_users]
GO
SET NOCOUNT ON
use [TARGETDB]
if exists (select * from dbo.sysobjects where id = object_id(N'[TARGETDB].[dbo].[conversion_forums]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
DROP TABLE [TARGETDB].[dbo].[conversion_forums]
GO
SET NOCOUNT ON
use [TARGETDB]
if exists (select * from dbo.sysobjects where id = object_id(N'[TARGETDB].[dbo].[cs_forums_topics]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
DROP TABLE [TARGETDB].[dbo].[cs_forums_topics]
GO

SET NOCOUNT ON
use [TARGETDB]
CREATE TABLE dbo.cs_forums_topics
	(
	threadid int NOT NULL,
	postid int NOT NULL,
	parentid int NOT NULL,
	topicid int NULL,
	postlevel int NULL
	)  ON [PRIMARY]
GO
SET NOCOUNT ON
use [TARGETDB]
ALTER TABLE dbo.cs_forums_topics ADD CONSTRAINT
	PK_cs_forums_topics PRIMARY KEY CLUSTERED 
	(
	threadid,
	postid,
	parentid
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO
SET NOCOUNT ON
use [TARGETDB]
CREATE TABLE dbo.conversion_users
	(
	olduserid int NOT NULL,
	newuserid int NOT NULL,
	membershipid uniqueidentifier NOT NULL
	)  ON [PRIMARY]
GO
SET NOCOUNT ON
use [TARGETDB]
ALTER TABLE dbo.conversion_users ADD CONSTRAINT
	PK_conversion_users PRIMARY KEY CLUSTERED 
	(
	olduserid
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]


GO
SET NOCOUNT ON
use [TARGETDB]
CREATE TABLE dbo.conversion_forums
	(
	sectionid int NOT NULL,
	forumid int NOT NULL
	)  ON [PRIMARY]
GO
SET NOCOUNT ON
use [TARGETDB]
ALTER TABLE dbo.conversion_forums ADD CONSTRAINT
	PK_conversion_forums PRIMARY KEY CLUSTERED 
	(
	forumid
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO

SET NOCOUNT ON
/* setup the portalid */
declare @portalid int 
set @portalid=0



use [SOURCEDB]
/* Fix DNN Passwords */
--get CS machinekeys and replace DNN keys
--set the HOST/ADMIN password/salt to be a known CS password(s)

/* set the applicationid for the aspnet tables */
declare @applicationid uniqueidentifier
set @applicationid = (select top 1 applicationid from [TARGETDB].dbo.aspnet_applications)

SET NOCOUNT ON
declare @registereduserrole int
set @registereduserrole = 1


declare @moduleid int
set @moduleid = forumMODULEID


/* get users from CS aspnet_users table into DNN aspnet_users table */

insert into [TARGETDB].dbo.aspnet_users
select
	@applicationid
	, au.userid
	, au.username
	, au.loweredusername
	, au.mobilealias
	, au.isanonymous
	, au.lastactivitydate
from 
[SOURCEDB].dbo.aspnet_users au 
where au.username not in (select username from [TARGETDB].dbo.aspnet_users)

SET NOCOUNT ON

/* add into to aspnet_membership for users */

insert into [TARGETDB].dbo.aspnet_membership
select
	@applicationid
	, am.userid
	, am.Password
	, am.PasswordFormat
	, am.PasswordSalt
	, am.MobilePin
	, am.email
	, am.loweredemail
	, am.passwordquestion
	, am.passwordanswer
	, am.IsApproved
	, am.IsLockedOut
	, am.CreateDate
	, am.LastLoginDate
	, am.LastPasswordChangedDate
	, am.LastLockoutDate
	, am.FailedPasswordAttemptCount
	, am.FailedPAsswordAttemptWindowStart
	, am.FailedPasswordAnswerAttemptCount
	, am.FailedPasswordAnswerAttemptWindowStart
	, am.Comment

from 
[SOURCEDB].dbo.aspnet_membership am 
where am.userid in (select userid from [TARGETDB].dbo.aspnet_users)


/* insert users into DNN users table replace first/last/display with valid profile info*/

insert into [TARGETDB].dbo.users
(username, firstname, lastname, email, displayname)
	select 
		au.username
		, au.username
		, au.username
		, am.email
		, au.username
	from
		[TARGETDB].dbo.aspnet_users au
		join [TARGETDB].dbo.aspnet_membership am on (au.userid = am.userid)
	where au.username not in (select username from [TARGETDB].dbo.users)
	and LEN(au.username) <50
	

/* insert users into DNN UserPortals table */
insert into [TARGETDB].dbo.userportals
(userid, portalid, createddate, authorised)
	select 
		u.userid
		, @portalid
		, GetDate()
		, 1
	from
		[TARGETDB].dbo.users u
	where u.userid not in (select userid from [TARGETDB].dbo.userportals where portalid=@portalid)

/* insert profile information into DNN Profile Table */
-- community server doesn't have much profile data, signature might be the only interesting one to get later

/* insert info into DNN UserRoles table */

insert into [TARGETDB].dbo.userroles
(userid, roleid)
	select 
		u.userid
		, @registereduserrole
	from
		[TARGETDB].dbo.users u
	where u.userid not in (select userid from [TARGETDB].dbo.userroles where roleid=@registereduserrole)


insert into [TARGETDB].dbo.UserProfile
(UserID, PropertyDefinitionID, PropertyValue,PropertyText,Visibility,LastUpdatedDate)
select u.userid, 21, u.firstname, null,2,GETDATE() from [TARGETDB].dbo.Users u where u.userid not in (select UserID from [TARGETDB].dbo.UserProfile where PropertyDefinitionID=21)

insert into [TARGETDB].dbo.UserProfile
(UserID, PropertyDefinitionID, PropertyValue,PropertyText,Visibility,LastUpdatedDate)
select u.userid, 23, u.LastName, null,2,GETDATE() from [TARGETDB].dbo.Users u where u.userid not in (select UserID from [TARGETDB].dbo.UserProfile where PropertyDefinitionID=23)

insert into [TARGETDB].dbo.forum_users
	(UserId, 
	Signature,
	PostCount,
	LastActivity,
	IsTrusted,
	EnableOnlineStatus,
	ThreadsPerPage,
	PostsPerPage,
	ViewDescending,
	EnableModNotification,
	EmailFormat,
	PortalId,
	EnablePublicEmail,
	TrackingDuration,
	LockTrust,
	IsBanned,
	LiftBanDate,
	EnableSelfNotifications,
	EnableProfileWeb,
	EnableDefaultPostNotify,
	StartBanDate)
	(select u.userid, --userid
	null, --signature
	0, --PostCount,
	GetDate(), --LastActivity,
	0, --IsTrusted,
	0, --EnableOnlineStatus,
	10, --ThreadsPerPage,
	5, --PostsPerPage,
	0, --ViewDescending,
	0, --EnableModNotification,
	1, --EmailFormat,
	@portalid, --PortalId,
	0, --EnablePublicEmail,
	1000, --TrackingDuration,
	0, --LockTrust,
	0, --IsBanned,
	null, --LiftBanDate,
	0, --EnableSelfNotifications,
	1, --EnableProfileWeb,
	0, --EnableDefaultPostNotify,
	null --StartBanDate)
		
	from [TARGETDB].dbo.users u where u.UserID not in (select UserID from [TARGETDB].dbo.forum_Users))


update [TARGETDB].dbo.UserRoles
set CreatedOnDate = GETDATE(), LastModifiedOnDate=GETDATE(), CreatedByUserID=1, LastModifiedByUserID=1
where CreatedOnDate is null


/* Get Forum Groups */

insert into  [TARGETDB].dbo.forum_groups
(Name, PortalId, ModuleId, SortOrder, CreatedDate, CreatedByUser, UpdatedByUser, UpdatedDate)
	select 
		cg.Name	
		, 0	
		, @ModuleId
		, cg.SortOrder
		, GetDate()
		, 1
		, 1
		, GetDate()
	from
		cs_groups cg
	where applicationtype=0
	
/* Get Forums */

insert into  [TARGETDB].dbo.forum_forums
	(GroupId
	, IsActive
	, ParentId
	, Name
	, Description
	, CreatedDate
	, CreatedByUser
	, UpdatedByUser
	, UpdatedDate
	, IsModerated
	, SortOrder
	, TotalPosts
	, TotalThreads
	--, MostRecentPostId
	--, MostRecentPostAuthorId
	--, MostRecentPostDate
	, PostsToModerate
	, ForumType
	, EnableModNotification
	, PublicView
	, PublicPosting
	, EnableForumsThreadStatus
	, EnableForumsRating
	, ForumLink
	, ForumBehavior
	, AllowPolls
	, EnableRSS
	, EmailAddress
	, EmailFriendlyFrom
	, NotifyByDefault
	, EmailStatusChange
	, EmailEnableSSL
	, EmailAuth
	, EmailPort
	, EnableSiteMap
	, SitemapPriority
	)
	
	(
	Select
		(select fg.groupid from [TARGETDB].dbo.forum_groups fg join cs_groups cg on (cg.name = fg.name) where cg.groupid=cs.GroupId) --GroupId
	, cs.IsActive -- IsActive
	, 0 --ParentId
	, cs.Name --Name
	, cs.Description --Description
	, cs.DateCreated --CreatedDate
	, 1 --CreatedByUser
	, 1 --UpdatedByUser
	, GetDate() --UpdatedDate
	, 0 --IsModerated
	, 1 --SortOrder
	, 0 --TotalPosts
	, 0 --TotalThreads
	--, MostRecentPostId
	--, MostRecentPostAuthorId
	--, MostRecentPostDate
	, 0 --PostsToModerate
	, 0 --ForumType
	, 0 --EnableModNotification
	, 1 --PublicView
	, 1 --PublicPosting
	, 0 --EnableForumsThreadStatus
	, 1 --EnableForumsRating
	, '' --ForumLink
	, 2 --ForumBehavior
	, 0 --AllowPolls
	, 1 --EnableRSS
	, 'admin@change.me' --EmailAddress
	, 'WEBSITENAME' --EmailFriendlyFrom
	, 0 -- NotifyByDefault
	, 0 --EmailStatusChange
	, 0 --EmailEnableSSL
	, 0 --EmailAuth
	, 110 --EmailPort
	, 1 --EnableSiteMap
	, 0.5 --SitemapPriority

	from
		cs_sections cs

	where groupid in (select groupid from cs_groups where applicationtype=0))



use [SOURCEDB]

SET NOCOUNT ON
--create table of old and new userids
insert [TARGETDB].[dbo].[conversion_users]
(olduserid, newuserid, membershipid)

(select cu.userid
		, dnu.userid
		, cu.membershipid
	from [TARGETDB].dbo.users dnu 
	join [TARGETDB].dbo.aspnet_users dnau on (dnu.username = dnau.username) 
	join aspnet_users au on (au.userid=dnau.userid)	join cs_users cu on (cu.membershipid = au.userid))

--create table of old and new forumids
insert [TARGETDB].[dbo].[conversion_forums]
(forumid, sectionid)
--(select af.forumid, cs.sectionid from [TARGETDB].dbo.forum_forums af join cs_sections cs on (cs.name = af.Name))

(select af.forumid, cs.sectionid from [TARGETDB].dbo.forum_forums af join cs_sections cs on (cs.name = af.Name) where 
cs.GroupID = (select csg.GroupID from cs_Groups csg join [TARGETDB].dbo.Forum_Groups afg on afg.Name =csg.Name where afg.GroupID = af.groupid ))

use [TARGETDB]
SET NOCOUNT ON
CREATE STATISTICS [_dta_stat_1174295243_2] ON [dbo].[conversion_users]([newuserid])


CREATE STATISTICS [_dta_stat_1142295129_2_5] ON [dbo].[cs_forums_topics]([postid], [postlevel])


CREATE NONCLUSTERED INDEX [_dta_index_cs_forums_topics_11_1142295129__K2_1_3] ON [dbo].[cs_forums_topics] 
(
	[postid] ASC
)
INCLUDE ( [threadid],
[parentid]) WITH (SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY]

SET NOCOUNT ON

/* Get Forum Threads Stored Procedure */
--save the postid from CS to the new ID in Forums
--match userid from CS to DNN using the aspnet_users userid

SET NOCOUNT ON
USE [TARGETDB]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Forum_Post_Add_Conversion]
    @ParentPostID INT,
    @ForumID INT,
    @UserID INT,
    @RemoteAddr NVARCHAR(100),
    @Subject NVARCHAR(255),
    @Body NVARCHAR(MAX),
    @IsPinned BIT,
    @PinnedDate DATETIME,
    @IsClosed BIT,
    @PortalID INT,
    @PollID INT,
    @IsModerated BIT,
    @ParseInfo INT,
    @PostDate DATETIME,
    @DateUpdated DATETIME

AS 
    DECLARE @PostID INT
    DECLARE @ThreadID INT
    DECLARE @CreatedDate DATETIME
    DECLARE @ModeratedForum BIT
    DECLARE @GroupID INT
    DECLARE @DateApproved DATETIME
    DECLARE @IsApproved BIT

    SELECT  @CreatedDate = @PostDate
	
    IF @IsModerated = 0 
        BEGIN
            SET @IsApproved = 1
            SET @DateApproved = GETDATE()
        END
    ELSE 
        BEGIN
            SET @IsApproved = 0
        END
        
    IF @ParentPostID = 0 -- New Thread
        BEGIN 	
            INSERT  dbo.Forum_Posts
                    (
                      ParentPostID,
                      UserID,
                      RemoteAddr,
                      [Subject],
                      Body,
                      CreatedDate,
                      UpdatedDate,
                      IsApproved,
                      IsClosed,
                      DateApproved,
                      ParseInfo,
				  PostReported
                    )
            VALUES  (
                      @ParentPostID,
                      @UserID,
                      @RemoteAddr,
                      @Subject,
                      @Body,
                      @CreatedDate,
                      @DateUpdated,
                      @IsApproved,
                      @IsClosed,
                      @DateApproved,
                      @ParseInfo,
				  0
                    ) 
            SELECT  @PostID = @@IDENTITY	
            SET @ThreadID = @PostID
            
            EXEC dbo.Forum_Thread_Add @ThreadID, @ForumID, @IsPinned,
                @PinnedDate, @PollID

            UPDATE  dbo.Forum_Posts
            SET     ThreadID = @ThreadID
            WHERE   PostID = @PostID			
        END
    ELSE -- Reply
        BEGIN
        
			SET @ThreadID = ( SELECT ThreadID FROM dbo.Forum_Posts WHERE PostID = @ParentPostID)
            INSERT  dbo.Forum_Posts
                    (
                      ParentPostID,
                      UserID,
                      RemoteAddr,
                      [Subject],
                      Body,
                      CreatedDate,
                      ThreadID,
                      UpdatedDate,
                      IsApproved,
                      IsClosed,
                      DateApproved,
                      ParseInfo,
				  PostReported
                    )
            VALUES  (
                      @ParentPostID,
                      @UserID,
                      @RemoteAddr,
                      @Subject,
                      @Body,
                      @CreatedDate,
                      @ThreadID,
                      @CreatedDate,
                      @IsApproved,
                      @IsClosed,
                      @DateApproved,
                      @ParseInfo,
				  0
                    )
            SELECT  @PostID = @@IDENTITY
            
                BEGIN		
                    EXEC dbo.Forum_AA_ThreadUpdate @ThreadID, @PostID,
                        @IsPinned, @PinnedDate, 'postadd', @PollID
                END	
        END	

        BEGIN
            EXEC dbo.Forum_AA_UserPostCountUpdate @UserID, @PortalID
            EXEC dbo.Forum_Forum_PostAdded @ForumID, @ThreadID,
                @PostID, @UserID, 'add'
        END
    SELECT  @PostID
	RETURN @PostID
GO
