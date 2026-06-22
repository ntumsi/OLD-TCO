@ModelType AMCOS.Logic.ViewModels.BaseViewModel

<div class="row pre-header expanded">
    @If Model.ShowPendingUsersNotification Then
        @<div class="medium-9 column">
            <a href="@Url.Content("~/App/Admin/AdminApproval.aspx")" id="lnkPendingAdmin" style="font-size:small; color:Red; text-decoration:underline" class="blinking">@Model.PendingUsersNotification</a>
        </div>
    End If
    @If ConfigurationManager.AppSettings("ShowUsersBannerNotification") = "true" Then
        @<div class="medium-9 column">
            <a id="usersBannerNotification" style="font-size:small; color:Red;">@ConfigurationManager.AppSettings("BannerNotificationText")</a>
        </div>
    End If
    <div id="preHeaderMenu" class="medium-3 column float-right text-right">
        <a id="AMCOSLogout" href="javascript:void(0);" onclick="window.location.replace('@Url.Content("~/Logout")')">&#10005; Logout</a>
    </div>
    <div id="SessionExpiring" class="cal-hidden">
        Your session will expire in less than 30 seconds.        
    </div>
</div>

<div class="row amcos-header expanded">
    <div class="small-9 large-4 column menu-logo-left">
        <img id="armyLogo" src="@Url.Content("~/dist/img/army.png")" alt="US ARMY" />
        <a href="@Url.Content("~/home")" title="Return to AMCOS Home Page"><img id="amcosLogo" style="object-fit: scale-down;" src="@Url.Content("~/dist/img/amcos.png")" alt="AMCOS" /></a>
    </div>
    <div class="small-3 large-1 column float-right">
        <a href="https://www.asafm.army.mil" target="_blank" title="Open the ASA (FM&C) Portal in a new window.">
            <img id="dasaLogo" style="object-fit: scale-down;" src="@Url.Content("~/dist/img/DASA.png")" alt="DASA" />
        </a>
    </div>
    <div class="large-7 column amcos-menu">
        <ul class="dropdown menu" data-dropdown-menu>
            <li>
                        <a href="@Url.Content("~/home")">Home</a>
            </li>
            <li class="is-dropdown-submenu-parent">
                <a href="#">Applications</a>
                <ul class="menu">
                    <li><a href="@Url.Content("~/app/lite/default.aspx")" target=''>AMCOS Lite</a></li>
                    <li><a href="@Url.Content("~/app/project/default.aspx")" target=''>Project Manager</a></li>                    
                    <li><a href="@Url.Content("~/Visualization/Xwalk")" target=''>Pay Plan Xwalk</a></li> 

                    @If ConfigurationManager.AppSettings("EnableCivilianPCS") = "True" Then
                        @<li><a href="@Url.Content("~/Civilian/PCS/Index")" target=''>Civilian PCS</a></li>
                    End If
                </ul>
            </li>
            <li Class="is-dropdown-submenu-parent">
                <a href = "#" > Data</a>
                <ul Class="menu">
                    <li> <a href = "@Url.Content("~/Visualization/Inventory")" target="" >Inventory</a></li>
                    <li> <a href = "@Url.Content("~/Visualization/PaySchedule")" target=''>Pay Schedule</a></li>                  
                    <li> <a href = "@Url.Content("~/Visualization/LocalityRateByZipCode")" target=''>GS Locality Rates By ZIP Code</a></li>                    
                </ul>
            </li>
            <li>
                            <a href = "@Url.Content("~/App/Admin/UpdateMyProfile.aspx")">My Profile</a>
            </li>
            @If Model.IsAdmin Then
                @<li Class="is-dropdown-submenu-parent" id="administrationItem" runat="server">
                    <a href="#" Class="menuHeading">Administration</a>
                    <ul Class="menu">
                        <li> <a href="@Url.Content("~/app/admin/userlist.aspx")" target=''>User List</a></li>
                        <li> <a href="@Url.Content("~/app/admin/log.aspx")" target=''>Event Log</a></li>
                        @If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-CostCompare") = "true" Then
                            @<li> <a href="@Url.Content("~/admin/costcomparenew")" target=''>Cost Compare</a></li>
                        Else
                            @<li> <a href="@Url.Content("~/admin/costcompare")" target=''>Cost Compare</a></li>
                        End If
                        @If ConfigurationManager.AppSettings("FeatureFlag-QuickSight-AdminReports") = "true" Then
                            @<li><a href="@Url.Content("~/admin/amcosliteusage")" target=''>AMCOS Lite Usage</a></li>
                            @<li><a href="@Url.Content("~/admin/amcosuserapprovals")" target=''>AMCOS User Approvals</a></li>
                            @<li><a href="@Url.Content("~/admin/amcosuserlogins")" target=''>AMCOS User Logins</a></li>
                            @<li><a href="@Url.Content("~/admin/currentactiveamcosusers")" target=''>Current Active AMCOS Users</a></li>
                        End If
                        <li><a href="@Url.Content("~/admin/helpspotdata")" target=''>HelpSpot Historical Data</a></li>
                    </ul>
                </li>
            End If
                        <li>
                            <a href="#" data-toggle="offCanvas">Help Docs</a>
                        </li>
                    </ul>
        </div>

</div>
