@ModelType AMCOS.Logic.ViewModels.CivPcsNtsViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>
<div class="row grid-x">
    <div class="column cell small-6">
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Is the Permanent Duty Station Isolated?</label>
            </div>
            <div class="column cell small-5">
                @Html.CheckBoxFor(Function(model) model.IsIsolatedDutyStation)
            </div>
        </div>        
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                If the civilian is being moved to an isolated location then the Government will pay for storage of those goods for up to 3 years.
            </li>
            <li>
                Per move.org the average cost of storage is $0.90 per sqft per month.  The default cost is for 300 sqft for 2 years.
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
                @Html.TextBoxFor(Function(model) model.NTSSubtotal, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
            </div>
        </td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.NTSSubtotal, New With {.Class = "summary-item-value", .Id = "NTSSubtotalValue"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Section 054306 of the Joint Travel Regulation (JTR) - <a href="https://www.defensetravel.dod.mil/Docs/perdiem/JTR.pdf#page=85" target="_blank">www.defensetravel.dod.mil</a>
    </li>
</ul>
