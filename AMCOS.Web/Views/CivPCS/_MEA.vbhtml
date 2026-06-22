@ModelType AMCOS.Logic.ViewModels.CivPcsMeaViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>    
</div>
<div class="row grid-x cal-info-div" style="margin: 20px 0px 30px 0px">
    <div class="column cell small-6">
        <div style="margin-bottom: 7px;">
            <strong>No Supporting Documentation</strong>
        </div>        
        <ul>
            <li>$<span id="MEACivilian">@Model.MEACivilian.ToString("N2")</span> or equivalent of 1 week's pay (whichever is lesser)- Civilian</li>
            <li>$<span id="MEACivilianAndSpouse">@Model.MEACivilianAndSpouse.ToString("N2")</span> or equivalent of 2 week's pay (whichever is lesser)- Civilian & Spouse</li>
        </ul>
    </div>
    <hr class="cal-vertical-divider" />
    <div class="column cell small-6">
        <div style="margin-bottom: 7px;">
            <strong>Supporting Documentation</strong>
        </div>        
        <ul>
            <li>
                Need receipt evidence (aggregate amount shouldn't exceed 1 week's basic pay) )- Civilian
            </li>
            <li>
                Need receipt evidence (aggregate amount shouldn't exceed 2 week's basic pay) - Civilian & Spouse
            </li>
        </ul>
    </div>
</div>
<div class="row grid-x">
    <div class="column cell small-6">
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Spouse?</label>
            </div>
            <div class="column cell small-5">
                @Html.CheckBoxFor(Function(model) model.MEAHasSpouse)
            </div>
        </div>
    </div>
    <div class="column cell small-6">
        
       
    </div>
</div>
<hr style="margin-top: -10px;" />
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td class="subtotal-value" style="width: 150px">
            <div class="input-group" style="margin-bottom: 0px;">
                <span class="input-group-label left">$</span>
                @Html.TextBoxFor(Function(model) model.MEASubtotal, New With {.Class = "input-group-field right text-right decimal-2"})
            </div>
        </td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.MEASubtotal, New With {.Class = "summary-item-value", .Id = "MEASubtotalValue"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Code of Federal Regulations - <a href="https://www.ecfr.gov/cgi-bin/text-idx?SID=7115d33735bd2495888b56b2026ca357&mc=true&node=pt41.4.302_616&rgn=div5#se41.4.302_616_13" target="_blank">www.ecfr.gov</a>
    </li>
    <li>
        See Joint Travel Regulation, Section 0541 and FTR, Part 302-16 for more detailed information on MEA eligibility and allowances.
    </li>
</ul>
