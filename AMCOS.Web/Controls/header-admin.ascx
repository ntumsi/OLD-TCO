<%@ Control Language="vb" AutoEventWireup="false" CodeBehind="header-admin.ascx.vb" Inherits="AMCOS.Web.header_admin" %>
<div class="row pre-header expanded">
    <div class="large-9 column">
        <asp:LinkButton runat="server" ID="lnkPendingAdmin" style="font-size:small; color:Red; text-decoration:underline" class="blinking">There are x AMCOS user accounts pending</asp:LinkButton>
    </div>
    <%If ConfigurationManager.AppSettings("ShowUsersBannerNotificaion") = "true" Then %>
      <div class="medium-9 column">
            <a id="usersBannerNotification" style="font-size:small; color:Red; "><%=ConfigurationManager.AppSettings("BannerNotificationText")%></a>
      </div>
    <%End If %>
    <div id="preHeaderMenu" class="large-3 column text-right">
        <a id="AMCOSLogout" href="javascript:void(0);" onclick="window.location.replace('<%= ResolveClientUrl("~/Logout") %>')">&#10005; Logout</a>
    </div>
    <div id="SessionExpiring" class="cal-hidden">
        Your session will expire in less than 30 seconds.        
    </div>
</div>
<div class="row amcos-header expanded">
    <div class="large-5 column menu-logo-left">
        <img id="armyLogo" src='<%= ResolveClientUrl("~/dist/img/army.png")%>' alt="US ARMY" />
        <a href='<%= ResolveClientUrl("~/home") %>' title="Return to AMCOS Home Page"><img id="amcosLogo" src='<%= ResolveClientUrl("~/dist/img/amcos.png")%>' alt="AMCOS" /></a>
        <img id="dasaLogoSmallScreen" class="hide-for-large show-for-small" src='<%= ResolveClientUrl("~/dist/img/DASA.png")%>' alt="DASA" />
    </div>
    <div class="large-5 column amcos-menu">
        <ul class="dropdown menu" data-dropdown-menu>
            <li>
                <a href='<%= ResolveClientUrl("~/home") %>'>Home</a>
            </li>
            <li class="is-dropdown-submenu-parent">
                <a href="#">Applications</a>
                <ul class="menu">
                    <li><a href='<%= ResolveClientUrl("~/app/lite/default.aspx")%>' target="_self" >AMCOS Lite</a></li>
                    <li><a href='<%= ResolveClientUrl("~/app/project/default.aspx")%>' target="_self">Project Manager</a></li>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-Xwalk") = "true" Then %>
                        <li><a href='<%= ResolveClientUrl("~/Visualization/Xwalk")%>' target='_self'>Pay Plan Xwalk</a></li>
                    <%Else %>
                        <li><a href='<%= ResolveClientUrl("~/Data/XWalk")%>' target='_self'>Pay Plan Xwalk</a></li>
                    <%End If %>                   
                    <%If ConfigurationManager.AppSettings("EnableCivilianPCS") = "True" Then %>
                        <li><a href='<%= ResolveClientUrl("~/Civilian/PCS/Index")%>' target='_self'>Civilian PCS</a></li>
                    <%End If %>
                </ul>
            </li>
            <li class="is-dropdown-submenu-parent">
                <a href="#">Data</a>
                <ul class="menu">
                    <li><a href='<%= ResolveClientUrl("~/Visualization/Inventory")%>' target="_self">Inventory</a></li>                   
                    <li><a href='<%= ResolveClientUrl("~/Visualization/PaySchedule")%>' target="_self">Pay Schedule</a></li> 
                    <li><a href='<%= ResolveClientUrl("~/Visualization/LocalityRateByZipCode")%>' target="_self">GS Locality Rates By ZIP Code</a></li>
                </ul>
            </li>
            <li>
                <a href='<%= ResolveClientUrl("~/App/Admin/UpdateMyProfile.aspx")%>'>My Profile</a>
            </li>
            <li class="is-dropdown-submenu-parent">
                <a href="#" class="menuHeading">Administration</a>
                <ul class="menu">
                    <li><a href='<%= ResolveClientUrl("~/app/admin/userlist.aspx")%>' target="_self">User List</a></li>
                    <li><a href='<%= ResolveClientUrl("~/app/admin/log.aspx")%>' target="_self">Event Log</a></li>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-CostCompare") = "true" Then %>
                    <li><a href='<%= ResolveClientUrl("~/admin/costcomparenew")%>' target="_self">Cost Compare</a></li>
                    <%Else %>
                    <li><a href='<%= ResolveClientUrl("~/admin/costcompare")%>' target="_self">Cost Compare</a></li>
                    <%End If %>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-AdminReports") = "true" Then %>
                    <li><a href='<%= ResolveClientUrl("~/admin/amcosliteusage")%>' target="_self">AMCOS Lite Usage</a></li>
                    <%End If %>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-AdminReports") = "true" Then %>
                    <li><a href='<%= ResolveClientUrl("~/admin/amcosuserapprovals")%>' target="_self">AMCOS User Approvals</a></li>
                    <%End If %>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-AdminReports") = "true" Then %>
                    <li><a href='<%= ResolveClientUrl("~/admin/amcosuserlogins")%>' target="_self">AMCOS User Logins</a></li>
                    <%End If %>
                    <%If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-AdminReports") = "true" Then %>
                    <li><a href='<%= ResolveClientUrl("~/admin/currentactiveamcosusers")%>' target="_self">Current Active AMCOS Users</a></li>
                    <%End If %>
                    <li><a href='<%= ResolveClientUrl("~/admin/helpspotdata")%>' target='_self'>HelpSpot Historical Data</a></li>
                </ul>
            </li>
            <li>
                <a href="#" data-toggle="offCanvas">Help Docs</a>
            </li>
        </ul>
    </div>
    <div class="large-2 column">
        <a href="https://www.asafm.army.mil" target="_blank" title="Open the ASA (FM&C) Portal in a new window.">
            <img id="dasaLogo" src='<%= ResolveClientUrl("~/dist/img/DASA.png")%>' alt="DASA" />
        </a>
    </div>
</div>
