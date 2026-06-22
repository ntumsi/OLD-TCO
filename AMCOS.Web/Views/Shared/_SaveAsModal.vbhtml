@ModelType AMCOS.Logic.Models.ISaveAsModel
<div Class="reveal cal-modal" id="@Model.ID" data-reveal data-options="closeOnClick:false;">
    <strong>@Model.Title</strong><a class="cal-icon close" data-tooltip title="Close" data-close>&times;</a>
    <div id="SaveAsModel" style="padding-top: 20px; padding-bottom: 20px;">
        @Html.Partial("_ViewProjects", Model.Values)
    </div>
    <label>Project Name</label>
    <input type="text" id="SaveAsProjectName" class="cal-input-wide" />
    <input type="button" value="Save" class="cal-button-dark" onclick="SaveAsClick();" data-close/>
</div>

