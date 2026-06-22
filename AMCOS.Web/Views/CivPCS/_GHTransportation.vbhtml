@ModelType AMCOS.Logic.ViewModels.CivPcsGoodsHomeTransportation

<div class="show-for-medium">
    <h4 class="show-for-medium">@Model.Title</h4>
    <hr />
</div>
<p style="font-size: medium">The government provides reimbursment for either house hold goods or mobile home transportation.  Please choose what you will be transporting.</p>
<div class="row grid-x">
    <div class="cell column small-12" style="padding-left: 40px">
        @Html.RadioButtonFor(Function(model) model.TransportationType, "Goods", New With {.Id = Guid.NewGuid(), .Class = "pcs-input-field"})<label> House Hold Goods</label>
    </div>
    <div class="cell column small-12" style="padding-left: 40px">
        @Html.RadioButtonFor(Function(model) model.TransportationType, "Home", New With {.Id = Guid.NewGuid(), .Class = "pcs-input-field"})<label> Mobile Home Transportation</label>
    </div>
</div>
<hr />
<div id="house-hold-goods">
    @Html.Partial("_HHG", Model.HHGTransportationModel)
</div>
<div id="mobile-home-transportation">
    @Html.Partial("_MobileHome", Model.HomeTranportationModel)
</div>
@Html.HiddenFor(Function(model) model.GHTransportationTotal, New With {.Class = "summary-item-value"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
