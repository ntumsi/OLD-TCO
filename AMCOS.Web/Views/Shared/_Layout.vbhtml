@ModelType AMCOS.Logic.ViewModels.BaseViewModel
<!DOCTYPE html>
<html class="no-js" xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta charset="utf-8" />
    <meta http-equiv="x-ua-compatible" content="ie=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewBag.Title</title>
    <link rel="alternate" type="application/rss+xml" title="Army Military-Civilian Cost System (AMCOS)" href="@Url.Content("~/Public/rss.xml")" />
    @RenderSection("AdditionalStyles", False)
    @System.Web.Optimization.Styles.Render("~/bundles/css")
    @System.Web.Optimization.Scripts.Render("~/bundles/jquery")
    <link rel="stylesheet" type="text/css" href="@Url.Content("~/dist/css/amcos-lite-chart.css")" />
    <link rel="stylesheet" type="text/css" href="@Url.Content("~/dist/css/selectize.Default.css")" />
    <link rel="stylesheet" type="text/css" href="@Url.Content("~/dist/css/c3.min.css")" />
</head>
<body style="background-color: #fafafa;">
    <input type="hidden" id="AntiForgeryToken" value="@ViewBag.AntiForgeryToken" />
    @Html.Partial("_SessionExpiringModal")
    <div class="off-canvas position-right" id="offCanvas" data-off-canvas data-transition="overlap">
        <ul>
            <li><span data-toggle="offCanvas">&times;</span></li>
            <li>
                <span>Primary Documents</span>
                <ul>
                    <li><a href="@Url.Content("~/Public/AMCOS CBA Guide.pdf")" target="_blank">Cost Benefit Analysis Guide</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS Fact Sheet.pdf")" target="_blank">Fact Sheet</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS FAQ.pdf")" target="_blank">Frequently Asked Questions</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS Release Update History.pdf")" target="_blank">Release Notes/Update History</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS Cost Model Documentation.pdf")" target="_blank">Cost Model Documentation</a></li>
                    <li><a href="@Url.Content("~/app/data/calculations.aspx")">Cost Element Data Dictionary</a></li>
                </ul>
            </li>
            <li>
                <span>Methodologies</span>
                <ul>
                    @*<li><a href="@Url.Content("~/Public/AMCOS Civilian Health Insurance Methodology.pdf")" target="_blank">Civilian Health Insurance</a></li>*@
                    <li><a href="@Url.Content("~/Public/Contractor Cost Estimate Methodology.pdf")" target="_blank">Contractor Cost Estimate</a></li>
                    <li><a href="@Url.Content("~/Public/Inflation and Discounting PVF Calculation Methodology.pdf")" target="_blank">Inflation and Discounting</a></li>
                    <li><a href="@Url.Content("~/Public/Pay Plan Xwalk Methodology.pdf")" target="_blank">Pay Plan Xwalk</a></li>
                    <li><a href="@Url.Content("~/Public/Salary Calculation Methodology.pdf")" target="_blank">Salary Calculation</a></li>
                </ul>
            </li>
            <li>
                <span>Tutorials</span>
                <ul>
                    <li><a href="@Url.Content("~/Public/AMCOS Civilian PCS.pdf")" target="_blank">AMCOS Civilian PCS</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS LITE Tutorial.pdf")" target="_blank">AMCOS Lite</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS Project Manager Tutorial.pdf")" target="_blank">AMCOS Project Manager</a></li>
                    <li><a href="@Url.Content("~/Public/AMCOS Pay Plan Xwalk Tutorial.pdf")" target="_blank">AMCOS Pay Plan Xwalk</a></li>
                    <li><a href="@Url.Content("~/Public/AESMP User Primer.pdf")" target="_blank">How to Submit a Request in AESMP</a></li>

                </ul>
            </li>
            <li>
                <a href="@Url.Content("~/Public/HistoricalDatabaseLinksList.pdf")" target="_blank">Data Exports prior to 2020</a>
            </li>
            <li>
                <a href="@Url.Content("~/Help/DataRequest")" target=''>Request Data Export</a>
            </li>
            <li>
                <a href="@Url.Content("~/Public/ARMY CES Xwalk.xlsx")" target="_blank">Army Current-Former CES Xwalk</a>
            </li>
        </ul>
    </div>
    <div class="off-canvas-content" data-off-canvas-content>
        @*<form id="amcos">*@
        <div id="contentArea">
            @RenderPage("~/Views/Shared/_Header.vbhtml", Model)
            @RenderBody()

        </div>
        @RenderPage("~/Views/Shared/_Footer.vbhtml")
        @*</form>*@
    </div>
    <script type="text/javascript" src='@Url.Content("~/dist/js/jquery.min.js")'></script>
    <script type="text/javascript" src='@Url.Content("~/dist/js/what-input.min.js")'></script>
    <script type="text/javascript" src='@Url.Content("~/dist/js/foundation.min.js")'></script>
    <script type="text/javascript">

        var _logoutURL = '@Url.Content("~/Logout")';
        var _validateSessionURL = '@Url.Content("~/Home/KeepAlive")';
        var _defaultYear = '@ConfigurationManager.AppSettings("DefaultYear")';
    </script>
    <script type="text/javascript" src="@Url.Content("~/dist/js/amcos-site.js")"></script>
    @RenderSection("AdditionalJavaScript", False)
</body>
</html>
