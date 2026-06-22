@ModelType AMCOS.Logic.ViewModels.VisualizationViewModel
@Code
    ViewBag.Title = Model.Title
    Layout = "~/Views/Shared/_Layout.vbhtml"
End Code

@Html.Partial("_QuickSight", Model)