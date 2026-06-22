@ModelType AMCOS.Logic.ViewModels.CivPcsRitaViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>
<p style="font-size: medium">
    Costs <u>include</u> Withholding Tax Allowance (WTA).  WTA is an advance of RITA to cover anticipated current year tax liability.  If you need to time phase RITA using WTA please do so in the export.
</p>
<div class="row grid-x">
    <div class="cell column small-6">
        <label>Estimated Federal Income Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.FederalTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        <label>Estimated Social Security Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.SocialSecurityTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        <label>Estimated Medicare Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.MedicareTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        @*<a data-tooltip title="Default Estimated Tax Rate - @Model.DefaultFederalIncomeTax.ToString("N2")%" style="font-size: small; text-align: right; border-bottom: none;" onclick="SetDefaultTax();">Set Default</a>*@
        <label>Estimated State Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.StateTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        <label>Estimated County Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.CountyTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        <label>Estimated City Tax Rate</label>
        <div class="input-group text-right" >
            @Html.TextBoxFor(Function(model) model.CityTaxRate, New With {.Class = "input-group-field text-center left decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
    </div>
    @Html.HiddenFor(Function(model) model.DefaultFederalTaxRate)
    <div class="cell column small-6">
        <ul>
            <li>
                Assumed a mandatory 22 percent federal income tax withholding, 6.2 percent Social Security tax, and 1.45 percent Medicare tax.
                Source: <a href="https://www.dfas.mil/CivilianEmployees/civrelo/Civilian-Moving-Expenses-Tax-Deduction/Current-PCS-Travel/" target="_blank">www.dfas.mil</a>
            </li>
            <li>
                AMCOS estimates the state and local tax impact to RITA but localites may have exceptions to their tax law for relocation expenses.
                For this reason be advised the displayed figure is an estimate and the actual amounts may vary.
            </li>
        </ul>
        <table class="cal-notice-table" style="margin-top: 40px">
            <tr>
                <th class="header-cell" style="text-align: left" >
                    <strong>Total Tax Rate</strong>
                </th>
            </tr>
            <tr>
                <td class="header-cell" style="padding-left: 20px"><span id="TotalTaxRate"></span>&nbsp;%</td>               
            </tr>           
        </table>
    </div>
</div>

<table class="cal-notice-table">
    <tr>
        <td class="header-cell">
            <table class="cal-info-table inner">
                <tr>
                    <td class="header-cell">
                        House Hunting Trip
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="HouseHuntingTotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="HouseHuntingRITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Transportation Expense
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="TransportationSubTotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="TransportationRITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Temporary Quarters Subsistence Expense
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="TQSESubtotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="TQSERITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Goods / Home Transportation
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="GHTransportationTotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="GHTransportationRITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Misc. Expense Allowance
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="MEASubtotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="MEARITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Real Estate / Lease Allowance
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="RealEstateLeaseTotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light"  style="text-align: right">
                        <span id="RealEstateLeaseRITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Non-Temporary Storage
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="NTSSubtotalLabel">0.00</span>&nbsp;&times;&nbsp;<span name="TaxBracketLabel"></span>
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        =
                    </td>
                    <td class="header-cell light" style="text-align: right">
                        <span id="NTSRITA" name="TaxSubtotal">0.00</span>
                    </td>
                </tr>
            </table>
        </td>
    </tr>
</table>
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td id="RITASubtotalValue" class="subtotal-value">$@Model.RITASubtotal.ToString("0.00")</td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.RITASubtotal, New With {.Class = "summary-item-value"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Federal Travel Regulation General Services Administration Bulletin 18-05, 302-1.1 dated May 14,2018
    </li>
    <li>
        Relocation Income Tax information - <a href="https://www.fs.fed.us/asc/bfm/programs/travel/tos/documents/RelocationIncomeTax2.pdf" target="_blank">(www.fs.fed.us) RelocationIncomeTax2.pdf</a>
    </li>
</ul>
