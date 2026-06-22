@ModelType AMCOS.Logic.ViewModels.CivPcsHouseHuntingViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>
<div class="row grid-x">
    <div class="column cell small-6">
        <div class="row grid-x" style="margin-bottom: 30px;">
            <div class="column cell small-7">
                <label>Number of Full Days for House Hunting</label>
            </div>
            <div class="column cell small-5">
                @Html.TextBoxFor(Function(model) model.NumberOfDaysHunting, New With {.Class = "text-right decimal-0 pcs-input-field"})
            </div>
        </div>
        <div class="row grid-x">
            <div class="column cell small-7">
                <label>Spouse?</label>
            </div>
            <div class="column cell small-5">
                <div class="input-group" style="margin-bottom: 0px;">
                    @Html.CheckBoxFor(Function(model) model.HouseHuntingHaveSpouse, New With {.Class = "pcs-input-field"})
                </div>
            </div>
        </div>
    </div>
    <div class="column cell small-6">
        <ul>
            <li>The calculation will add travel days so do not include them in this number.</li>
            <li>The number of house hunting days is determined by the Administrative Officer (AO) according to the  DoD Financial Management Regulation (FMR) 7000.14 Volume 09 (Travel Policy) and DODI 515431.</li>
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
                        Self Per Diem
                    </td>
                    <td id="SelfLodgingPerDiem" class="info-cell dark">@(String.Format("${0}", Model.SelfLodgingPerDiem.ToString("0.00")))</td>
                    <td id="SelfMIEPerDiem" class="info-cell dark">@(String.Format("${0}", Model.SelfMIEPerDiem.ToString("0.00")))</td>
                </tr>
                <tr>
                    <td class="header-cell" style="padding-left: 20px">
                        Spouse Per Diem*
                    </td>
                    <td id="SpouseLodgingPerDiem" class="info-cell dark">@(String.Format("${0}", Model.SpouseLodgingPerDiem.ToString("0.00")))</td>
                    <td id="SpouseMIEPerDiem" class="info-cell dark">@(String.Format("${0}", Model.SpouseMIEPerDiem.ToString("0.00")))</td>
                </tr>
            </table>
        </td>
    </tr>
</table>
<p style="margin-top: -15px">
    *Spouse per diem is <span id="SpousePerDiemRate">@((Model.SpousePerDiemRate * 100).ToString("N0"))</span>% of the full per diem.
</p>
<table class="cal-subtotal">
    <tr>
        <td>Subtotal (@Model.Title):</td>
        <td id="HouseHuntingTotalCell" class="subtotal-value">$@Model.HouseHuntingTotal.ToString("0.00")</td>
    </tr>
</table>
@Html.HiddenFor(Function(model) model.HouseHuntingTotal, New With {.Class = "summary-item-value"})
@Html.HiddenFor(Function(model) model.Title, New With {.Class = "summary-item-title", .Id = Guid.NewGuid().ToString()})
<small style="text-decoration: underline">Policy References</small>
<ul>
    <li>
        Section 054005 of the Joint Travel Regulation (JTR) - <a href="https://www.defensetravel.dod.mil/Docs/perdiem/JTR.pdf" target="_blank">(www.defensetravel.dod.mil) JTR.pdf</a>
    </li>
</ul>

