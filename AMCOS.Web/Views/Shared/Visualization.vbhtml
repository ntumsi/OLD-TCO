@ModelType AMCOS.Logic.ViewModels.VisualizationViewModel
@Code
    ViewBag.Title = Model.Title
    Layout = "~/Views/Shared/_Layout.vbhtml"
End Code

@* Model.View selects the partial: "_LocalVisualization" (default local C3 chart) or the
   legacy "_QuickSight" embed. *@
@Html.Partial(Model.View, Model)