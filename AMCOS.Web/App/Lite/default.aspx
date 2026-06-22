<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.LiteDefault" Title="AMCOS Lite" Codebehind="default.aspx.vb" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <asp:HiddenField ID="selectedPayPlan" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedPayPlanText" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCostSummary" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCategoryGroupCode" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCategorySubgroupCode" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCareerProgramNumber" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedLocationId" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedLocationText" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedScienceTechnologyReinventionLaboratory" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedDependentStatusText" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedNumberOfDependents" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputOverheadPercent" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedInflationConversionType" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedInflationYear" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="hidUserId" ClientIDMode="Static" runat="server" />
    <div class="reportPage">
        <h1>AMCOS Lite</h1>
        <p class="summary">
            This tool allows you to view costs for specified personnel. The grid immediately below shows the totals by appropriation for the selected Cost Summary.
        </p>
        <div class="leftPanel">
            <div class="row column">
                <label for="payPlanList">Pay Plan</label>
                <select id="payPlanList" class="demo-default selectized extended-width"></select>
            </div>
            <div id="categoryFilter" class="column row hide">
                <label id="categoryLabel" for="categoryList">Category</label>
                <select id="categoryList" class="demo-default selectized extended-width"></select>
            </div>
            <div id="locationFilter" class="column row hide">
                <label id="locationLabel" for="locationList">Location</label>
                <select id="locationList" class="demo-default selectized extended-width"></select>
            </div>
            <div id="scienceTechnologyReinventionLaboratoryFilter" class="column row hide">
                <label id="scienceTechnologyReinventionLaboratoryListLabel" for="scienceTechnologyReinventionLaboratoryList">Science and Technology Reinvention Laboratory (STRL)</label>
                <select id="scienceTechnologyReinventionLaboratoryList" class="demo-default selectized"></select>
            </div>
            <div id="dependentStatusFilter" class="column row hide">
                <label id="dependentStatusLabel" for="dependentStatusList">Dependent Status</label>
                <select id="dependentStatusList" class="demo-default selectized"></select>
            </div>
            <div id="numberOfDependentsFilter" class="column row hide">
                <label id="numberOfDependentsLabel" for="numberOfDependentsList">Number of Dependents</label>
                <select id="numberOfDependentsList" class="demo-default selectized"></select>
            </div>
            <div id="overheadPercentFilter" class="column row hide">
                    <label for="overheadPercent">Overhead Percent</label>
                    Enter a number between 0 - 200 and press Enter key: &nbsp;<input type="number" id="overheadPercent" step="any" min="0" max="200" title="Please enter a valid number between 0 and 200">%
            </div>
            <div id="inflationFilter" class="column row hide">
                <div class="column row">
                    <label for="inflationConversionTypeList">Inflation (Base/Input Year:  <b><% =ConfigurationManager.AppSettings().Get("DefaultYear") %></b>)</label>
                    <select id="inflationConversionTypeList">
                        <option value="ThenToConstant">Then Year to Constant Dollars</option>
                        <option value="ThenToThen" selected>Then Year to Then Year</option>
                    </select>
                </div>
                <div class="column row">
                    <label for="inflationYearList">Output/Target Year</label>
                    <select id="inflationYearList"></select>
                </div>
            </div>
            <div id="costSummaryFilter" class="column row hide">
                <label for="costSummaryList">Summary</label>
                <select id="costSummaryList"></select>
            </div>
            <div runat="server" id="exportButton" class="column row hide" ClientIDMode="Static">
                <label for="ibDownloadExcel">Download</label>
                <asp:ImageButton ID="ibDownloadExcel" runat="server" ImageUrl="~/dist/img/ms-excel.gif" Width="20px" ClientIDMode="Static" />
            </div>
            <div class="column row text-center">
                <asp:Button runat="server" ID="showCostsButton" ClientIDMode="Static" Text="Refresh Cost Table" OnClientClick="stopBlink(); alertForAllCostSummary(); return validateFilters();" CssClass="fullWidth" /> &nbsp;
            </div>
        </div>
        <div class="rightPanel">
            <asp:UpdatePanel id="AppropriationGroupSummaryUpdatePanel" runat="server">
                <ContentTemplate>
                    <div class="tableWrapper">
                        <asp:GridView ID="AppropriationGroupGridView" runat="server" ClientIDMode="Static" ShowFooter="True" CellPadding="3">
                            <FooterStyle BackColor="#DEDFDE" />
                            <HeaderStyle BackColor="Black" ForeColor="White" Font-Bold="true" HorizontalAlign="Center" />
                            <EmptyDataTemplate>
                                No Data Avaliable
                            </EmptyDataTemplate>
                        </asp:GridView>
                    </div>
                </ContentTemplate>
                <Triggers>
                    <asp:AsyncPostBackTrigger ControlID="ShowCostsButton" EventName="Click" />
                </Triggers>
            </asp:UpdatePanel>            
            <div class="row">
                <div class="small-12 column">
                    <ul style='color: black;font-size:smaller'>
                        <li id="weaponSystemWarning" class="hide">
                            Based on OSD CAPE's 2020 Operating and Support Cost Estimating Guide published in Sep 2020, Army CES 5.06 or DoD CES 6.0 is no longer necessary for acquisition life cycle cost estimates but remains necessary for other estimates. Impacted items are highlighted in orange in the above summary table.
                        </li>
                        <li>
                            Only use Contractor Cost Estimate (CCE) if there is not an existing or similar contract available.
                        </li>
                        <li>
                            Need a list of all locality rates or the locality rate for a specific zip code?  If so, navigate to Data Tab -> Zip Code tool.
                        </li>
                        <li>
                            AMCOS is in compliance with OSD DODI 7041.04.
                        </li>
                        <li>
                            User <span style='color: Red;font-weight:bolder'>MUST</span> always click on the <span style='color: Red;font-weight:bolder'>FLASHING RED</span> &ldquo;Refresh Cost Table&rdquo; button in order to refresh the cost screen display and retrieve the desired selection(s).
                        </li>
                        <li id="gfebsSelectAllWarning">
                            Please be aware that when selecting ALL from the drop down, AMCOS returns the average of all available Cost Elements (CEs).  Not all CEs may be applicable to your analysis, e.g., Non-Foreign COLA or Overseas Allowances.  They only apply to positions located in areas that receive these benefits.
                        </li>
                    </ul>
                </div>
            </div>
            <h3 id="h3InflationRatesHeader">
                <asp:Label runat="server" ID="InflationRatesHeaderLabel"></asp:Label>
            </h3>
            <asp:UpdatePanel id="InflationRatesUpdatePanel" runat="server">
                <ContentTemplate>
                    <div class="tableWrapper">
                        <asp:GridView ID="InflationRatesGridView" runat="server" CellPadding="5" EmptyDataText="No Data" ClientIDMode="Static">
                            <FooterStyle BackColor="#DEDFDE" />
                            <HeaderStyle BackColor="Black" ForeColor="White" Font-Bold="true" />
                        </asp:GridView>
                    </div>
                </ContentTemplate>
                <Triggers>
                    <asp:AsyncPostBackTrigger ControlID="ShowCostsButton" EventName="Click" />
                </Triggers>
            </asp:UpdatePanel>
            <h3 id="h3CostHeader">
                <asp:Label runat="server" ID="lblPayTableTitle"></asp:Label>
            </h3>                   
            <div class="column row">
                <ul class="tabs" data-tabs id="amcosLiteResultTabs">
                    <li class="tabs-title is-active"><a href="#tabularPanel" aria-selected="true">Tabular Results</a></li>
                    <li class="tabs-title"><a data-tabs-target="chartPanel" href="#chartPanel">Graph Results</a></li>
                </ul>
                <div class="tabs-content" data-tabs-content="amcosLiteResultTabs">
                    <div class="tabs-panel is-active" id="tabularPanel">
                        <asp:UpdatePanel ID="CostsUpdatePanel" runat="server">
                            <ContentTemplate>
                                <asp:GridView ID="CostsGridView" runat="server" ClientIDMode="Static" CellPadding="5" EmptyDataText="No Data" EnableViewState="False" >
                                    <FooterStyle BackColor="#DEDFDE" />
                                    <HeaderStyle BackColor="Black" ForeColor="White" Font-Bold="true" />
                                </asp:GridView>
                            </ContentTemplate>
                            <Triggers>
                                <asp:AsyncPostBackTrigger ControlID="ShowCostsButton" EventName="Click" />
                            </Triggers>
                        </asp:UpdatePanel>
                    </div>
                    <div class="tabs-panel" id="chartPanel">
                        <div id="amcosLiteChart"></div>
                    </div>
                </div>
            </div>
            <div id="cceNote" class="column row hide">
                <b>Note:</b>
                <ul>
                    <li runat="server" id="liHighlightNote" visible="false">The highlighted field indicates a wage greater than <% =FormatCurrency(cceMaxPayFootnote, 2) %> per year.</li>
                    <li>The Avg Cost of Salary - Private Industry wages and salaries accounted for <% =FormatPercent(_cceWagesAndSalaries, 1) %> of employer compensation costs.</li>
                    <li>
                        The Avg Cost of Benefits account for the remaining <% =FormatPercent(_cceBenefitsAll, 1) %> of employer compensation (Avg Cost of Salary * <% =FormatNumber(_cceBenefitsAll, 3) %> = Benefits).
                    </li>
                    <li>Benefits include:
                        <ul>
                            <li>Paid leave (<% =FormatPercent(_cceBenefitsPaidLeave, 1) %>).</li>
                            <li>Supplemental pay (<% =FormatPercent(_cceBenefitsSupplementalPay, 1) %>).</li>
                            <li>Insurance (<% =FormatPercent(_cceBenefitsInsurance, 1) %>).</li>
                            <li>Retirement and savings (<% = FormatPercent(_cceBenefitsRetirementAndSavingsAll, 1) %>).</li>
                            <li>Legally required (<% = FormatPercent(_cceBenefitsLegallyRequired, 1) %>) - Provides workers and their families with retirement income and medical care, mitigate economic hardship resulting from loss of work and disability, and cover liabilities resulting from workplace injuries and illnesses.</li>
                        </ul>
                    </li>
                    <li>A value of negative one [($1.00)] indicates a wage estimate is not available</li>
                </ul>
            </div>
        </div>
        <div class="clearfix">&nbsp;</div>
    </div>
</asp:Content>

<asp:Content ID="JSContent" ContentPlaceHolderID="JSPlaceHolder" runat="server">
    <script type="text/javascript" src="../../dist/js/object-inflationyear.min.js"></script>
    <script type="text/javascript" src="../../dist/js/object-payplan.min.js"></script>
    <script type="text/javascript" src="../../dist/js/d3.min.js"></script>
    <script type="text/javascript" src="../../dist/js/c3.min.js"></script>
    <script type="text/javascript" src="../../dist/js/selectize.min.js"></script>    
    <script type="text/javascript">
        var exports = {};
    </script>
    <script type="text/javascript" src="../../dist/js/amcos-common.js"></script>
    <script type="text/javascript" src="../../dist/js/amcos-lite.js"></script>
    
</asp:Content>