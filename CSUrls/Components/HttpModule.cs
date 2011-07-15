
using System;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using DotNetNuke.Common;
using DotNetNuke.Common.Utilities;
using DotNetNuke.Entities.Modules;
using DotNetNuke.Entities.Portals;
using DotNetNuke.Services.Exceptions;
using Microsoft.ApplicationBlocks.Data;

namespace com.christoc.modules.CSUrls.Components
{
    ///<summary>
    ///</summary>
    public class HttpModule : IHttpModule
    {
        //TODO: fix connection string
        private readonly string _connectionString = Config.GetConnectionString();

        ///<summary>
        /// Set the portalid, taking the current request and locating which portal is being called based on this request.
        /// </summary>
        /// <param name="request">request</param>
        private static void SetPortalId(HttpRequest request)
        {

            string domainName = Globals.GetDomainName(request, true);

            PortalAliasInfo pai = PortalSettings.GetPortalAliasInfo(domainName);
            if (pai != null)
                PortalId = pai.PortalID;
        }

        ///<summary>
        ///</summary>
        public static int PortalId { get; set; }

        #region Implementation of IHttpModule

        public void Init(HttpApplication context)
        {
            context.PreRequestHandlerExecute += (PreRequestHandlerExecute);
        }

        public void Dispose()
        {

        }

        #endregion

        private void PreRequestHandlerExecute(object source, EventArgs ea)
        {
            //((HttpApplication)source).Response.Write("begin PreRequestHandlerExecute <br />");
            //((HttpApplication)source).Response.Write(((HttpApplication)source).Request.Url.AbsoluteUri);

            CsRead(source);
        }

        private void CsRead(object source)
        {
            try
            {

                //TODO: This handler needs updated for Active_Forums, forum threads only work for DNN's core Forum right now.

                if(source!=null)
                {
                    
                }

                var application = (HttpApplication)source;
                HttpContext context = application.Context;
                HttpResponse response = context.Response;

                //because we're coming into a URL that isn't being handled by DNN we need to figure out the PortalId
                SetPortalId(context.Request);


                string href = string.Empty;
                //start looking for information in the URL
                string rawUrl = HttpContext.Current.Request.Url.AbsoluteUri;

                //response.Write("absoluteuri: " + rawUrl + "<br />");
                //response.Write("rawurl: " + HttpContext.Current.Request.RawUrl + "<br />");

                if (rawUrl.IndexOf("csdir") > 0)
                {
                    //response.Write("raw url: " + rawUrl + "<br />");
                    //get modulecontroller for later use
                    var mc = new ModuleController();

                    //tags
                    object ts = context.Request.QueryString["Tags"];
                    if (ts != null && href == string.Empty)
                    {
                        //lookup for the search results module
                        var milocal = mc.GetModuleByDefinition(PortalId, "Search Results");
                        href = Globals.NavigateURL(milocal.TabID, string.Empty,
                                                        "&Tag=" + ts);

                        //href = "http://www.sccaforums.com/SearchResults/TabId/42/default.aspx?tag=" + tagParameters.ToString();
                    }

                    int postid;
                    int forumid;
                    int groupid;
                    string postName;
                    int tabId=-1;
                    /* setup some DNN values we will use */
                    mc = new ModuleController();

                    //get the ModuleInfo for the Forum Module
                    var mi = mc.GetModuleByDefinition(PortalId, "Forum");

                    if(mi!=null)
                    //set the tabId to be the tabid of the Forum module, we're assuming we only have one forum module
                    tabId = mi.TabID;

                    /*
                     * First we're going to see if there's a PostID query string parameter, if so look up 
                     */
                    object o = context.Request.QueryString["PostID"];

                    if (o != null)
                    {
                        if (Int32.TryParse(o.ToString(), out postid))
                        {
                            var sql = new StringBuilder(150);
                            //look up the new forum information from DotNetNuke, based on post id which we match to the mapping table

                            sql.Append("select forumid, ft.threadid, fp.postid");
                            sql.Append(" from cs_forums_topics ftop ");
                            sql.Append(" join Forum_Posts fp on (fp.PostID = ftop.topicid)	");
                            sql.Append(" join Forum_Threads ft on (fp.ThreadID = ft.ThreadID) ");
                            sql.Append(" where ftop.postid = ");
                            sql.Append(postid.ToString());

                            //using Microsoft.ApplicationBlocks.Data's SqlHelper execute the sql
                            SqlDataReader result = SqlHelper.ExecuteReader(_connectionString, System.Data.CommandType.Text, sql.ToString());

                            while (result.Read())
                            {
                                href = Globals.NavigateURL(tabId, string.Empty,
                                                           "&forumid=" + result["forumid"] + "&postid=" + result["threadid"] +
                                                           "&scope=posts");

                                //the original string I used for building out the URL
                                //href = "http://www.sccaforums.com/forums/forumid/" + result["forumid"] + "/postid/" + result["threadid"] + "/scope/posts";
                            }

                            result.Close();

                        }
                    }

                    /*
                     * in the case of a ForumID in the querystring we need to look up the new ID and send them there 
                     */
                    object f = context.Request.QueryString["ForumID"];
                    //http://www.sccaforums.com/forums/forumid/6/scope/threads

                    if (f != null && href == string.Empty)
                    {
                        if (Int32.TryParse(f.ToString(), out forumid))
                        {
                            var sql = new StringBuilder(150);

                            sql.Append("select forumid from conversion_forums where sectionid= ");

                            sql.Append(forumid.ToString());

                            var result = SqlHelper.ExecuteScalar(_connectionString, System.Data.CommandType.Text, sql.ToString());
                            if (Int32.TryParse(result.ToString(), out forumid))
                            {
                                href = Globals.NavigateURL(tabId, string.Empty,
                                                           "&forumid=" + result + "&scope=threads");
                                //href = "http://www.sccaforums.com/forums/forumid/" + forumid.ToString() + "/scope/threads";
                            }
                        }
                    }

                    /*
                     * in the case of a Groupid in the querystring we need to look up the new ID and send them there 
                     */
                    object g = context.Request.QueryString["GroupID"];
                    //http://www.sccaforums.com/forums/groupid/4

                    if (g != null && href == string.Empty)
                    {
                        if (Int32.TryParse(g.ToString(), out groupid))
                        {
                            var sql = new StringBuilder(150);
                            sql.Append("select newgroupid from conversion_groups where oldgroupid = ");
                            sql.Append(groupid.ToString());

                            object result = SqlHelper.ExecuteScalar(_connectionString, System.Data.CommandType.Text, sql.ToString());
                            int resultid;
                            if (result != null && Int32.TryParse(result.ToString(), out resultid))
                            {
                                href = Globals.NavigateURL(tabId, string.Empty,
                                                           "&groupid=" + result);
                                //href = "http://www.sccaforums.com/forums/groupid/" + resultid.ToString();
                            }
                        }
                    }

                    /*
                     * Here we are doing a lookup sending blog posts/names to their new DNNSimpleArticle url
                     */

                    object pn = context.Request.QueryString["PostName"];
                    
                    if (pn != null && href == string.Empty)
                    {
                        
                        postName = pn.ToString();
                        var sql = new StringBuilder(150);
                        int oldPostId;
                        
                        if (Int32.TryParse(pn.ToString(), out oldPostId))
                        {
                            
                            sql.Append("select * from [cs_blog_topics] where postid=");
                            sql.Append(oldPostId);
                        }
                        else
                        {
                            sql.Append("select articleId from cs_blog_topics where postname= '");
                            sql.Append(postName.Replace("-", " "));
                            sql.Append("'");
                        }

                        //response.Write("before sql" + sql.ToString());

                        object result = SqlHelper.ExecuteScalar(_connectionString, System.Data.CommandType.Text, sql.ToString());
                        //response.Write("after sql" + result);
                        if (Int32.TryParse(result.ToString(), out postid))
                        {
                            //response.Write("inside parse sql result");
                            var milocal = mc.GetModuleByDefinition(PortalId, "DNNSimpleArticle");
                            href = Globals.NavigateURL(milocal.TabID, string.Empty,
                                                          "&aid=" + postid);

                            //href = "http://www.sccaforums.com/home/aid/" + postid;
                        }
                    }
                    if (href != string.Empty)
                    {
                        context.Response.Status = "301 Moved Permanently";
                        context.Response.RedirectLocation = href;
                    }
                }

            }
            catch (Exception exc)
            {
                Exceptions.ProcessPageLoadException(exc);

                var application = (HttpApplication)source;
                HttpContext context = application.Context;
                HttpResponse response = context.Response;

                context.Response.Status = "301 Moved Permanently";
                context.Response.RedirectLocation = "/";

                /*
                 * var application = (HttpApplication)source;
                
                 * HttpContext context = application.Context;
                
                 * HttpResponse response = context.Response;
                
                 * response.Write(exc.ToString());
                 */
            }

        }
    }
}