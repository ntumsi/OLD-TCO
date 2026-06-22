@ModelType AMCOS.Logic.Models.IOpenProjectModel
<div Class="reveal cal-modal" id="@Model.ID" data-reveal>
    <strong>@Model.Title</strong><a class="cal-icon close" data-tooltip title="Close" data-close>&times;</a>
    <div id="OpenProjectModel" style="padding-top: 20px; padding-bottom: 20px;">
        @Html.Partial("_ViewProjects", Model.Values)
    </div>
    <input type="button" value="Open Project" class="cal-button-dark" onclick="OpenProjectClick('@Model.ID');" />
</div>
