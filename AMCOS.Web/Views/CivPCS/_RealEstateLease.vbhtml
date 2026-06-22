@ModelType AMCOS.Logic.ViewModels.CivPcsRealEstateLease

<div class="show-for-medium">
    <h4 class="show-for-medium">@Model.Title</h4>
    <hr />
</div>
<p style="font-size: medium">The government provides reimbursement for either the sale and purchase of a home, or for the fee associated with early termination of an unexpired residential lease.  Please select from the following:</p>
<div class="row grid-x">
    <div class="cell column small-12" style="padding-left: 40px">
        @Html.RadioButtonFor(Function(model) model.RealEstateOrLease, "RealEstate", New With {.Id = Guid.NewGuid(), .Class = "pcs-input-field"})<label> Real Estate Allowance</label>
    </div>
    <div class="cell column small-12" style="padding-left: 40px">
        @Html.RadioButtonFor(Function(model) model.RealEstateOrLease, "Lease", New With {.Id = Guid.NewGuid(), .Class = "pcs-input-field"})<label> Unexpired Lease (UEL) Reimbursement</label>
    </div>
</div>
<hr />
<div id="Real-Estate">
    @Html.Partial("_RealEstate", Model.RealEstateModel)
</div>
<div id="Unexpired-Lease">
    @Html.Partial("_Lease", Model.LeaseModel)
</div>
@Html.HiddenFor(Function(model) model.RealEstateLeaseTotal, New With {.Class = "summary-item-value"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
