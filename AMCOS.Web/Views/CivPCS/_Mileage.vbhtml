@ModelType AMCOS.Logic.ViewModels.CivPcsMileageViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
    <hr />
</div>
<div class="row grid-x">
    <div class="column cell small-12">
        <label>Origination</label>
        @*@Html.DropDownListFor(Function(model) model.SourceLocation, Model.LocationList, New With {.Placeholder = "Enter City or Zip"})*@
        <select id="SourceLocation" placeholder="Enter City or Zip"></select>
    </div>
</div>
<div class="row grid-x">
    <div class="column cell small-12" style="margin-top: 10px">
        <label>Destination</label>
        @*@Html.DropDownListFor(Function(model) model.TargetDestination, Model.LocationList, New With {.Placeholder = "Enter City or Zip"})*@
        <select id="TargetDestination" placeholder="Enter City or Zip"></select>
    </div>
</div>
<hr />
<p>
    
</p>
<div class="row grid-x">
    <div class="column cell small-6">
        <label>Distance</label>
        <div class="input-group" style="margin-bottom: 0px;">
            @Html.TextBoxFor(Function(model) model.CalculatedDistance, New With {.Class = "input-group-field left decimal-0 text-right"})
            <span class="input-group-label right">Miles</span>
        </div>
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                The official DoD distance between two locations is available at <a href="https://dtod.transport.mil/Default.aspx" target="_blank">dtod.transport.mil</a>.
                AMCOS estimates that distance but users needing greater precision should consult this site and change the estimated mileage.
            </li>
        </ul>
    </div>
</div>
<hr />
<div class="row grid-x" style="margin-bottom: 1rem;">
    <div class="column cell small-6">
        <label for="ConversionType">Inflation (Base/Input Year:  <b id="AmcosVersionYear">@Model.AmcosVersionId.ToString().Substring(0, 4)</b>)</label>
        <select id="ConversionType" name="ConversionType" style="font-size: 1rem" class="pcs-input-rebase">
            <option value="ThenToConstant">Then Year to Constant Dollars</option>
            <option value="ThenToThen" selected>Then Year to Then Year</option>
        </select>

        <label>Appropriation</label>
        @Html.DropDownListFor(Function(model) model.Appropriation, Model.AppropriationList, New With {.Style = "font-size: 1rem"})

        <label>Output/Target Year</label>
        @Html.DropDownListFor(Function(model) model.Year, Model.YearList, New With {.Class = "pcs-input-rebase", .Style = "font-size: 1rem"})
    </div>
    <div class="column cell small-6">
        <ul>
            <li>
                Constant Dollars: Have been normalized for inflation (not escalation) 
                and for different expenditure patterns over time. (Use for Cost Analysis)
            </li>
            <li>
                Then Year Dollars: Include impact of inflation/escalation over the years of actual expenditure (outlay). (Use for Budgeting)
            </li>
            <li>
                The inflation rate based on your selection is ~<span id="JicInflationRate">@(Model.JicInflationRate.ToString("N6"))</span>.
            </li>
        </ul>
    </div>
</div>

@Html.HiddenFor(Function(model) model.AmcosVersionId)
<input type="hidden" id="CivLocationPerDiemURL" value="@Url.Action("GetAllLocations")" />
<input type="hidden" id="CalculateAllURL" value="@Url.Action("CalculateAll")" />
<input type="hidden" id="CivPCSLocationsById" value="@Url.Action("GetSpecificLocations")" />
<input type="hidden" id="CivPCSLocationsURL" value="@Url.Action("GetLocations")" />
<input type="hidden" id="GetYearListURL" value="@Url.Action("GetYearList")" />
<input type="hidden" id="CivPCSSaveProjectURL" value="@Url.Action("SaveProject")" />
<input type="hidden" id="CivPCSOpenProjectURL" value="@Url.Action("OpenProject")" />
<input type="hidden" id="CivPCSExportURL" value="@Url.Action("Export")" />
<input type="hidden" id="CivPCSDeleteProjectURL" value="@Url.Action("DeleteProject")" />
<input type="hidden" id="CivPCSSortProjectsURL" value="@Url.Action("SortProjects")" />


