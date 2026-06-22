@ModelType AMCOS.Logic.Models.IPcsModel
@Code
    ViewBag.Title = Model.Title
    Layout = "~/Views/Shared/_Layout.vbhtml"
End Code
@Section AdditionalJavascript
    @System.Web.Optimization.Scripts.Render("~/bundles/selectize")
    @System.Web.Optimization.Scripts.Render("~/bundles/civilian-pcs")
End Section

<div style="padding-bottom: 60px;">
    <div class="grid-x row cal-pill-title show-for-large">
        <div class="cell column small-12">
            <strong>@Model.Title</strong>
        </div>
    </div>
    <div class="hide-for-large">
        <div class="grid-x row cal-app-title-small">
            <div class="cell column small-12">
                <strong>@Model.Title</strong>
            </div>
        </div>
        <div class="grid-x row cal-utility-bar">
            <div class="cell columns small-7 text-left" style="white-space: nowrap">
                <a class="cal-icon" data-tooltip title="Open Project" data-open="@Model.OpenProjectModal.ID">&#x1F5C1; </a>
                <a class="cal-icon" data-tooltip title="Save As" data-open="@Model.SaveAsModal.ID">&#x1F5AB; </a>
                <a class="cal-icon" data-tooltip title="Export" tabindex="0" onclick="ExportClick();">&#x2399; </a>
                <span class="pcs-project-name"></span>
            </div>
            <div class="pcs-summary-total text-right cell columns small-5" style="margin-top: 3px;">
                <strong> Total :    $</strong><strong class="StrongTotal">0.00</strong>
            </div>
        </div>
    </div>
    <div class="grid-x row">
        <div class="cell column medium-4 large-3" style="padding: 0px;">
            <ul class="vertical tabs cal-vertical-menu" data-responsive-accordion-tabs="tabs small-accordion medium-tabs" id="PCSSideBar">
                @For x As Integer = 0 To Model.Content.Count - 1
                    If x <> 0 Then
                        @<li class="cal-line"></li>
                    End If
                    @<li class="cal-sidebar-button tabs-title pcs-content no-border @(If(x = 0, "is-active", ""))"><a id="PCSContentLink@(x)" class="cal-tabs-title" href="#PCSContent@(x)" onclick="AutoSavePCSContent();" @(If(x = 0, "aria-selected=""true""", ""))>@Model.Content(x).Title</a></li>
                Next
            </ul>
        </div>
        <div class="cell column medium-8 large-6 pcs-content">
            <div Class="tabs-content" data-tabs-content="PCSSideBar" id="PCSTabsContent">
                @For x As Integer = 0 To Model.Content.Count - 1
                    @<div class="tabs-panel @(If(x = 0, "is-active", ""))" id="PCSContent@(x)">
                        @Html.Partial(Model.Content(x).View, Model.Content(x))
                        <div class="row align-middle" style="margin-top: 30px;">
                            <div class="column cell medium-4 column-block show-for-medium text-left" style="margin-bottom: 1rem;">
                                @If x > 0 Then
                                    @<a class="cal-nav-button" onclick="PreviousTab();">&#x276C;<span> PREVIOUS</span></a>
                                End If
                            </div>
                            <div class="column cell medium-4 text-center column-block" style="margin-top: 8px">

                            </div>
                            <div class="columns cell medium-4 column-block show-for-medium text-right" style="margin-bottom: 1rem;">
                                @If x < Model.Content.Count - 1 Then
                                    @<a class="cal-nav-button" onclick="NextTab();"><span>NEXT </span>&#x276D;</a>
                                End If
                            </div>
                        </div>

                    </div>
                Next
            </div>
        </div>
        <div class="cell column large-3 " style="padding: 0px; margin-bottom: 25px;">
            <div id="PCSSummary" class="card pcs-summary show-for-large">
                <div class="cell columns text-left" style="white-space: nowrap">
                    <a class="cal-icon" data-tooltip title="Open Project" data-open="@Model.OpenProjectModal.ID">&#x1F5C1; </a>
                    <a class="cal-icon" data-tooltip title="Save As" data-open="@Model.SaveAsModal.ID">&#x1F5AB; </a>
                    <a class="cal-icon" data-tooltip title="Export" tabindex="0" onclick="ExportClick();">&#x2399; </a>
                    <span class="pcs-project-name"></span>
                </div>
                <div class="card-section pcs-summary-summary ">
                    <hr />
                    <strong> Summary</strong>
                    <table id="pcs-summary-table"></table>
                    <hr />
                </div>
                <div class="card-section pcs-summary-total text-right cell columns" style="margin-top: 3px;">
                    <strong> Total :    $</strong><strong class="StrongTotal">0.00</strong>
                </div>
            </div>

            @Html.Partial("_OpenProjectModal", Model.OpenProjectModal)
            @Html.Partial("_SaveAsModal", Model.SaveAsModal)
        </div>
    </div>
</div>
<div class="cal-autosaved">
    <span style="font-size: x-large">&#x1F5AB; &nbsp;</span><span style="font-size: medium;">AUTO-SAVED</span>
</div>
<input type="hidden" id="PCSContentCount" value="@Model.Content.Count" />



