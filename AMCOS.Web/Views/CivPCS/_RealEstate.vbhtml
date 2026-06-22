@ModelType AMCOS.Logic.ViewModels.CivPcsRealEstateViewModel

<h4 style="font-size: large; margin-bottom: 30px;">@Model.Title</h4>
<div class="row grid-x">
    <div class="column cell small-6">
        <label>Old Residence Sale Price Amount</label>
        <div class="input-group">
            <span class="input-group-label left">$</span>
            @Html.TextBoxFor(Function(model) model.SalePriceAmount, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
        </div>
        <label>Refund of Sale Price</label>
        <div class="input-group" style="margin-bottom: 25px;">
            @Html.TextBoxFor(Function(model) model.SalePriceRefund, New With {.Class = "input-group-field left text-right decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
        <label>New Residence Purchase Price Amount</label>
        <div class="input-group" >
            <span class="input-group-label left">$</span>
            @Html.TextBoxFor(Function(model) model.PurchasePriceAmount, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
        </div>
        <label>Refund of Purchase Price</label>
        <div class="input-group" style="margin-bottom: 0px;">
            @Html.TextBoxFor(Function(model) model.PurchasePriceRefund, New With {.Class = "input-group-field left text-right decimal-2 pcs-input-field"})
            <span class="input-group-label right">%</span>
        </div>
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                Amcos assumes that 8% and 3% are reasonable planning percentages but cirumstances
                may require upwards or downwards adjustments to those.
            </li>
            <li>
                10% Maximum refund of Sale Price
            </li>
            <li>
                5% Maximum refund of Purchase Price
            </li>
            <li>
                ($ * %) + ($ * %) = Total
            </li>
        </ul>
    </div>
</div>
<hr />
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td id="RealEstateSubtotalValue" class="subtotal-value">$@Model.RealEstateSubtotal.ToString("0.00")</td>
    </tr>
</table>
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Section 054502 of the Joint Travel Regulation (JTR)
    </li>
</ul>