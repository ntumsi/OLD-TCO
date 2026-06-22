@ModelType AMCOS.Logic.ViewModels.CivPcsLeaseViewModel

<h4 style="font-size: large; margin-bottom: 30px;">@Model.Title</h4>
<div class="row grid-x">
    <div class="column cell small-6">
        <label>Unexpired Lease (UEL) Amount</label>
        <div class="input-group" style="margin-bottom: 25px;">
            <span class="input-group-label left">$</span>
            @Html.TextBoxFor(Function(model) model.UELAmount, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
        </div>       
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                Reimbursement is prorated when the lease is not in the name of the employee and/or their dependent
            </li>            
        </ul>
    </div>
</div>
<hr />
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td id="UELTotalValue" class="subtotal-value">$@Model.UELTotal.ToString("0.00")</td>
    </tr>
</table>
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Section 054507 of the Joint Travel Regulation (JTR)
    </li>
</ul>