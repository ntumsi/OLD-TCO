@ModelType AMCOS.Logic.ViewModels.CivPcsTqseViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>

<div class="row grid-x">
    <div class="column cell small-6">
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Number of Full Days for TQSE</label>
            </div>
            <div class="column cell small-5">
                @Html.TextBoxFor(Function(model) model.NumberDaysTQSE, New With {.Class = "text-right decimal-0 pcs-input-field"})
            </div>
        </div>
        <div class="row grid-x">
            <div class="column cell small-7">
                <label>Dependent(s)?<br /><small>(child or adult)</small></label>
            </div>
            <div class="column cell small-5">
                <input id="TQSEDependents" type="text" pattern="[0-9]*" class="text-right decimal-0 pcs-input-field" min="0" max="999" value="0"/>
            </div>
        </div>
    </div>
    <div class="column cell small-6">
        <ul>
            <li>The calculation will add travel days so do not include them in this number.</li>
            <li>
                The number of TQSE days is determined by the Administrative Officer (AO) according to the DoD Joint Travel Regulation.
            </li>
            <li>
                TQSE should also include Foreign Transfer Allowance (FTA).
            </li>
        </ul>
    </div>
</div>
<table class="cal-notice-table">
    <tr>
        <td class="header-cell">
            <table class="cal-info-table inner">
                <tr>
                    <th class="header-cell" style="text-align: left"><strong>Per Diem Rate Per Day based on Destination</strong></th>
                    <th class="header-cell dark" style="width: 100px; text-align: right"><strong>Lodging</strong></th>
                    <th class="header-cell dark" style="width: 100px; text-align: right"><strong>MI&amp;E</strong></th>
                </tr>
                <tr>
                    <td class="header-cell" style="padding-left: 20px">
                        Self Per Diem*
                    </td>
                    <td class="info-cell dark" id="TQSESelfPerDiemLodging">@(String.Format("${0}", Model.TQSESelfPerDiemLodging.ToString("0.00")))</td>
                    <td class="info-cell dark" id="TQSESelfPerDiemMIE">@(String.Format("${0}", Model.TQSESelfPerDiemMIE.ToString("0.00")))</td>
                </tr>
                <tr>
                    <td class="header-cell" style="padding-left: 20px">
                        Dependent Per Diem**
                    </td>
                    <td class="info-cell dark" id="TQSESpousePerDiemLodging">@(String.Format("${0}", Model.TQSESpousePerDiemLodging.ToString("0.00")))</td>
                    <td class="info-cell dark" id="TQSESpousePerDiemMIE">@(String.Format("${0}", Model.TQSESpousePerDiemMIE.ToString("0.00")))</td>
                </tr>
            </table>
        </td>
    </tr>
</table>
<p style="margin-top: -15px">
    *Civilian per diem is <span id="TQSEPerDiemRate">@Model.TQSEPerDiemRate.ToString("N2")</span> times the Maximum per diem rate.<br />
    **Dependent per diem is <span id="TQSESpousePerDiemRate">@Model.TQSESpousePerDiemRate.ToString("N2")</span> times the Maximum per diem rate.
</p>
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td class="subtotal-value" id="TQSETotalValue">$@Model.TQSETotal.ToString("0.00")</td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.TQSETotal, New With {.Class = "summary-item-value"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Code of Federal Regulations-PCS : <a href="https://www.govinfo.gov/content/pkg/CFR-2012-title41-vol4/xml/CFR-2012-title41-vol4-part302-id829-subpartC.xml" target="_blank">www.govinfo.gov</a>
    </li>
</ul>
