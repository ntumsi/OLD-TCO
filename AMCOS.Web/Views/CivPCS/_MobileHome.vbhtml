@ModelType AMCOS.Logic.ViewModels.CivPcsMobileHomeViewModel

<h4 style="font-size: large; margin-bottom: 30px;">@Model.Title</h4>

<div>
    <div class="row grid-x">
        <div class="column cell small-6">
                <label>Total Mileage</label>               
                <div class="input-group">
                    @Html.TextBoxFor(Function(model) model.MobileHomeTotalMileage, New With {.Class = "input-group-field left text-right decimal-0 pcs-input-field"})
                    <span class="input-group-label right">Miles</span>
                </div>
               
                <label>Est. Cost per Mile</label>                
                <div class="input-group">
                    <span class="input-group-label left">$</span>
                    @Html.TextBoxFor(Function(model) model.MobileHomeEstCostPerMile, New With {.Class = "input-group-field right text-right decimal-2 pcs-input-field"})
                </div>
        </div>
        <div class="column cell small-6">
            <ul>               
                <li>
                    Estimated cost to move a mobile home is $<span id="MobileHomeEstCostPerMileValue">@Model.MobileHomeEstCostPerMile.ToString("N2")</span>/mile - <a href="https://homeguides.sfgate.com/average-cost-deliver-set-up-mobile-home-96554.html" target="_blank">homeguides.sfgate.com</a>
                </li>
                <li>
                    To have a mobile home transported at Government expense, you must certify that the mobile home will be used at the new official station as your primary residence and/or the primary residence of your immediate family according to section 302-10.3 of the mobile home code of  federal regulations.
                </li>
            </ul>
        </div>
    </div>
    <hr />
    <table class="cal-subtotal">
        <tr>
            <td>Subtotal (@Model.Title):</td>
            <td class="subtotal-value" id="MobileHomeSubtotal">
                $@Model.MobileHomeSubtotal.ToString("0.00")
            </td>
        </tr>
    </table>
    <small style="text-decoration: underline">Policy References</small>
    <ul>
        <li>
            Code of Federal Regulations-PCS : <a href="https://www.ecfr.gov/cgi-bin/text-idx?SID=60462e432ae1c3776460c92c83b03328&mc=true&node=pt41.4.302_610&rgn=div5#se41.4.302_610_11" target="_blank">www.ecfr.gov</a>
        </li>
    </ul>

</div>