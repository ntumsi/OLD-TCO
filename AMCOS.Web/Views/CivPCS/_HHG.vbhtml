@ModelType AMCOS.Logic.ViewModels.CivPcsHhgViewModel

<h4 style="font-size: large; margin-bottom: 30px;">@Model.Title</h4>

<div>
    <div class="row grid-x">
        <div class="column cell small-6">

            <label>Total Mileage</label>
            <div class="input-group" >
                @Html.TextBoxFor(Function(model) model.HHGTotalMileage, New With {.Class = "input-group-field left text-right decimal-0 pcs-input-field"})
                <span class="input-group-label right">Miles</span>
            </div>

            <label>Total Weight</label>
            <div class="input-group">
                @Html.TextBoxFor(Function(model) model.HHGTotalWeight, New With {.Class = "input-group-field left text-right decimal-0 pcs-input-field"})
                <span class="input-group-label right">Lbs.</span>
            </div>
            <small class="text-danger" id="HHGTotalWeightWarning"></small>

            <label>Est. Cost per Pound</label>
            <div class="input-group">
                <span class="input-group-label left">$</span>
                @Html.TextBoxFor(Function(model) model.HHGEstimatedCostPerPound, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
            </div>
            <label>Est. Cost per Mile</label>
            <div class="input-group" >
                <span class="input-group-label left">$</span>
                @Html.TextBoxFor(Function(model) model.HHGEstimatedCostPerMile, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
            </div>

        </div>
        <div class="column cell small-6">
            <ul>
                <li>
                    Civilian Employee & Dependents - Maximum Weight to Ship at no cost to the Civilian Employee is <span id="HHGMaxWeight">@Model.HHGMaxWeight.ToString("N0")</span> lbs.
                </li>
                <li>
                    Estimated Cost per mile $<span id="HHGEstimatedCostPerMileValue">@Model.HHGEstimatedCostPerMile.ToString("N2")</span>, Estimated Cost per pound $<span id="HHGEstimatedCostPerPoundValue">@Model.HHGEstimatedCostPerPound.ToString("N2")</span> according to a public domain - <a href="https://www.movers.com/moving-guides/how-do-movers-calculate-costs.html">www.movers.com</a>
                </li>
            </ul>
            <table class="cal-notice-table" style="margin-top: 40px">
                <tr>
                    <th class="header-cell" style="text-align: left" colspan="2">
                        <strong>Cost Estimations</strong>
                    </th>
                </tr>
                <tr>
                    <td class="header-cell" style="padding-left: 20px">Est. Cost by Total Miles</td>
                    <td class="info-cell" id="HHGCostByTotalMiles">
                        $@Model.HHGCostByTotalMiles.ToString("0.00")
                    </td>
                </tr>
                <tr>
                    <td class="header-cell" style="padding-left: 20px">Est. Cost by Total Weight</td>
                    <td class="info-cell" id="HHGCostByTotalWeight">
                        $@Model.HHGCostByTotalWeight.ToString("0.00")
                    </td>
                </tr>
            </table>
        </div>
    </div>
    <hr />
    <table class="cal-subtotal">
        <tr>
            <td>Subtotal (@Model.Title):</td>
            <td class="subtotal-value" id="SubtotalHHG">
                $@Model.SubtotalHHG.ToString("0.00")
            </td>
        </tr>
    </table>
    <small style="text-decoration: underline">Policy References</small>
    <ul>
        <li>
            Federal Regulations on HHG - <a href="https://www.govinfo.gov/content/pkg/CFR-2012-title41-vol4/xml/CFR-2012-title41-vol4-part302-id879-subpartA.xml" target="_blank">www.govinfo.gov</a>
        </li>
        <li>
            Defense Travel Management Office #3 (HHG) - <a href="https://www.defensetravel.dod.mil/site/faqpcs.cfm" target="_blank">www.defensetravel.dod.mil</a>
        </li>
    </ul>

</div>