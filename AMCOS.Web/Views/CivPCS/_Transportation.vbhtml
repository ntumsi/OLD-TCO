@ModelType AMCOS.Logic.ViewModels.CivPcsTransportationViewModel
<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>

<div class="row grid-x">
    <div class="column cell small-6">
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Total Mileage</label>
            </div>
            <div class="column cell small-5">
                @Html.TextBoxFor(Function(model) model.POVMileage, New With {.Class = "text-right decimal-0 "})
            </div>
        </div>
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Dependent(s)?<br /><small>(child or adult)</small></label>
            </div>
            <div class="column cell small-5">
                <input id="TransportationDependents" type="text" pattern="[0-9]*" min="0" max="999" class="text-right decimal-0 pcs-input-field" value="0" />
            </div>
        </div>
        <table class="cal-notice-table" style="margin-top: 40px">
            <tr>
                <th class="header-cell" style="text-align: left" colspan="2">
                    <strong>Mileage Rate</strong>
                </th>
            </tr>
            <tr>
                <td class="header-cell" style="padding-left: 20px">Self</td>
                <td class="info-cell" id="MileageReimbursement">
                    $@Model.MileageReimbursement.ToString("0.00")
                </td>
            </tr>
            <tr>
                <td class="header-cell" style="padding-left: 20px">Dependents</td>
                <td class="info-cell" id="DependantMileageReimbursement">
                    $@Model.DependantMileageReimbursement.ToString("0.00")
                </td>
            </tr>
        </table>
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                The mode of transportation (Car, Airplane, Motorcycle) is determined by the Administrative Officer (AO).
            </li>
            <li>
                The Government will consider the needs of the traveler, the purpose of travel, the cost, and other factors and then do one of the following: Provide Government transportation. Purchase commercial transportation on behalf of the traveler, Reimburse the traveler for personally purchased transportation, Reimburse the traveler for use of a privately owned vehicle (POV) according to section 050101 of the Dept. of Defense Joint Travel Regulation(JTR).
            </li>
            <li>
                Estimating $<span id="PCSMaltRate">@Model.PCSMaltRate.ToString("N2")</span>/Mile based on rates as of January 1, <span id="TransportationVersionYear">@Model.TransportationVersionYear</span> from the Defense Travel Management Office Monetary Allowance in Lieu Transportation <a href="https://www.defensetravel.dod.mil/site/otherratesMile.cfm" target="_blank">(MALT)</a> and adjusted for inflation if applicable.
            </li>
        </ul>
    </div>
</div>
<hr />
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td class="subtotal-value" style="width: 150px">
            <div class="input-group" style="margin-bottom: 0px;">
                <span class="input-group-label left">$</span>
                @Html.TextBoxFor(Function(model) model.TransportationSubTotal, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
            </div>
        </td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.TransportationSubTotal, New With {.Class = "summary-item-value", .Id = "TransportationSubTotalValue"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Sections 050101, 053802 Of the Joint Travel Regulation (JTR)-<a href="https://www.defensetravel.dod.mil/Docs/perdiem/JTR.pdf#page=85" target="_blank">https://www.defensetravel.dod.mil/Docs/perdiem/JTR.pdf#page=85</a>
    </li>
</ul>
