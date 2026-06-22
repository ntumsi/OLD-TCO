<%@ Control Language="vb" AutoEventWireup="false" CodeBehind="header-user.ascx.vb" Inherits="AMCOS.Web.header_user" %>
<%If ConfigurationManager.AppSettings("ShowUsersBannerNotificaion") = "true" Then %>
      <div class="medium-9 column">
            <a id="usersBannerNotification" style="font-size:small; color:Red; "><%=ConfigurationManager.AppSettings("BannerNotificationText")%></a>
      </div>
<%End If %>
<div class="row column expanded text-right pre-header">
    <a id="AMCOSLogout" href="javascript:void(0);" onclick="window.location.replace('<%= ResolveClientUrl("~/Logout") %>')">&#10005; Logout</a>
</div>
<div id="SessionExpiring" class="cal-hidden">
        Your session will expire in less than 30 seconds.        
    </div>
<div class="row amcos-header expanded">
    <div class="column large-5 menu-logo-left">
        <img id="armyLogo" src='<%= ResolveClientUrl("~/dist/img/army.png")%>' alt="US ARMY" />
        <a href='<%= ResolveClientUrl("~/home") %>' title="Return to AMCOS Home Page"><img id="amcosLogo" src='<%= ResolveClientUrl("~/dist/img/amcos.png")%>' alt="AMCOS" /></a>
        <img id="dasaLogoSmallScreen" class="hide-for-large show-for-small" src='<%= ResolveClientUrl("~/dist/img/DASA.png")%>' alt="DASA" />
    </div>
    <div class="column large-5 amcos-menu">
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
            <li>
                <a href="#" data-toggle="offCanvas">Help Docs</a>
            </li>
        </ul>
    </div>
    <div class="column large-2">
        <a href="https://www.asafm.army.mil" target="_blank" title="Open the ASA (FM&C) Portal in a new window.">
            <img id="dasaLogo" src='<%= ResolveClientUrl("~/dist/img/DASA.png")%>' alt="DASA" />
        </a>
    </div>
</div>
