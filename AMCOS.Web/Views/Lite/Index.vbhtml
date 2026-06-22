@Code
    ViewData("Title") = "Index"
    Layout = "~/Areas/AppNew/Views/Shared/_Layout.vbhtml"
End Code

<div>
    <asp:HiddenField ID="hidDownload" Value="" runat="server"></asp:HiddenField>
    <div class="reportPage">
        <h1>AMCOS Lite</h1>
        <p class="summary">
            This tool allows you to view costs for specified personnel. The grid immediately below shows the totals by appropriation for the selected Cost Summary.
        </p>
        <div class="leftPanel">
            <div class="row">
                <div class="small-12 column">
                    <label for="PayPlanList">Pay Plan</label>
                    <select ID="PayPlanList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                    <label for="CostSummaryList">Summary</label>
                    <select ID="CostSummaryList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                    <label id="lblCategoryGroup" for="CategoryGroupList">Group</label>
                    <select ID="CategoryGroupList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div id="categorySubgroupFilter">
                <div class="row">
                    <div class="small-12 column">
                        <label id="lblCategorySubgroup" for="CategorySubgroupList">Subgroup</label>
                        <select ID="CategorySubgroupList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                    </div>
                </div>
            </div>
            <div id="gfebsFilters">
                <div class="row">
                    <div class="small-12 column">
                        <label for="StateCountryList">State / Country</label>
                        <select ID="StateCountryList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                    </div>
                </div>
                <div class="row">
                    <div class="small-12 column">
                        <label for="FunctionalAreaList">Functional Area</label>
                        <select ID="FunctionalAreaList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                    </div>
                </div>
                <div class="row">
                    <div class="small-12 column">
                        <label for="CostCenterList">Cost Center</label>
                        <select ID="CostCenterList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                    </div>
                </div>
            </div>
            <div id="occupationalSeriesSubtitleFilters">
                <div class="small-12 column">
                    <label for="OccupationalSeriesSubtitleList">Occupational Series Subtitle</label>
                    <select ID="OccupationalSeriesSubtitleList" AutoPostBack="true"></select>
                </div>
            </div>
            <div id="localityFilters">
                <div class="small-12 column">
                    <label for="LocalityList">Locality / Location</label>
                    <select ID="LocalityList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div id="metroAreaFilters">
                <div class="small-12 column">
                    <label for="MetroAreaList">Area</label>
                    <select ID="MetroAreaList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div id="overheadPercentageFilters">
                <div class="small-12 column">
                    Overhead Percentage<br />
                    <br />
                    Enter a number between 0 - 200 and press Enter key: &nbsp;<input type="text" ID="CCEOverheadPercentage" Text="0" AutoPostBack="true" />%
                    <label ID="lblErrMsg" ForeColor="Red" Visible="false"><br />* Must be a numeric value between 0 and 200</label>
                </div>
            </div>
            <div ID="inflationFilters">
                <div class="small-12 column">
                    <label for="InflationConversionTypeList">Inflation (Base/Input Year:  <b>2019</b>)</label>
                    <select ID="InflationConversionTypeList" AutoPostBack="true">
                        <option Text="Then Year to Constant Dollars" Value="ThenToConstant"></option>
                        <option Text="Then Year to Then Year" Value="ThenToThen" Selected="True"></option>
                    </select>
                </div>
                <div class="small-12 column">
                    <label for="InflationYearList">Output/Target Year</label>
                    <select ID="InflationYearList" AutoPostBack="true" DataValueField="Value" DataTextField="Text"></select>
                </div>
            </div>
            <div ID="pnlExportIcons" CssClass="row" Visible="false">
                <div class="small-12 column hidden">
                    <div ID="lblDownload" Text="Download"></div>
                    <button ID="ibDownloadExcel" ImageUrl="~/dist/img/ms-excel.gif" Width="20px"></button>
                </div>
            </div>
            <div class="row text-center">
                <div class="small-12 column">
                    <button ID="ShowCostsButton" Text="Refresh Cost Table Based on Locality/Location %" OnClientClick="stopBlink(); alertForAllCostSummary(); return true;" CssClass="fullWidth"></button> &nbsp;
                </div>
            </div>
        </div>
        <div class="rightPanel">
            <div id="divGSWarning" style="color: #FF0000; font-size: 18px;" visible="False">
                The Special Pay Scales listed in AMCOS show all of the occupations, grade levels, and locations where the Special Scale applies. If you can find exactly what you are looking for with respect to the occupation, grade level, and&nbsp; location in the table below, then it is covered by the Special Scale and this table should be used. If not, it is not covered by the Special Scale and you should use the GS pay plan to find the correct data.
            </div>
            <div class="tableWrapper">
                @Code
                    Dim appropriationSummaryGrid As WebGrid = New WebGrid(Model)
                End Code
                @appropriationSummaryGrid.GetHtml
            </div>
            <div class="row">
                <div class="small-12 column">
                    <ul style='color: black;font-size:smaller'>
                        <li>
                            Only use Contractor Cost Estimate (CCE) if there is not an existing or similar contract available.
                        </li>
                        <li>
                            Need a list of all the locality rates or what the locality rate for a specific zip code?  If so, navigate to Data Tab -> Zip Code tool.
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
                <label ID="InflationRatesHeaderLabel"></label>
            </h3>
            <div class="tableWrapper">
                @Code
                    Dim inflationRateGrid As WebGrid = New WebGrid(Model)
                End Code
                @inflationRateGrid.GetHtml
            </div>
            <h3 id="h3CostHeader">
                <label ID="lblPayTableTitle"></label>
            </h3>
            <div class="tableWrapper">
                @Code
                    Dim costsGrid As WebGrid = New WebGrid(Model)
                End Code
                @costsGrid.GetHtml
            </div>
            <div id="cceNote">
                <b>Note:</b>
                <ul>
                    <li id="liHighlightNote" visible="false">The highlighted field indicates a wage greater than $239,200 per year.</li>
                    <li>The Avg Cost of Salary - Private Industry wages and salaries accounted for @*<% =FormatPercent(_cceWagesAndSalaries, 1) %>*@ of employer compensation costs.</li>
                    <li>
                        The Avg Cost of Benefits account for the remaining @*<% =FormatPercent(_cceBenefitsAll, 1) %>*@ of employer compensation (Avg Cost of Salary * @*<% =FormatNumber(_cceBenefitsAll, 3) %>*@ = Benefits).
                    </li>
                    <li>
                        Benefits include:
                        <ul>
                            <li>Paid leave (@*<% =FormatPercent(_cceBenefitsPaidLeave, 1) %>*@).</li>
                            <li>Supplemental pay (@*<% =FormatPercent(_cceBenefitsSupplementalPay, 1) %>*@).</li>
                            <li>Insurance (@*<% =FormatPercent(_cceBenefitsInsurance, 1) %>*@).</li>
                            <li>Retirement and savings (@*<% = FormatPercent(_cceBenefitsRetirementAndSavingsAll, 1) %>*@).</li>
                            <li>Legally required (@*<% = FormatPercent(_cceBenefitsLegallyRequired, 1) %>*@) - Provides workers and their families with retirement income and medical care, mitigate economic hardship resulting from loss of work and disability, and cover liabilities resulting from workplace injuries and illnesses.</li>
                        </ul>
                    </li>
                    <li>A value of negative one [($1.00)] indicates a wage estimate is not available</li>
                </ul>
            </div>
        </div>
        <div class="clearfix">&nbsp;</div>
    </div>

</div>