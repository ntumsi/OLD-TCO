@ModelType AMCOS.Logic.ViewModels.VisualizationViewModel
<div width="100%" height="100%" id="embeddedQuickSightContent"></div>
<script type="text/javascript" src='@Url.Content("~/dist/js/quicksight-embedding-js-sdk.min.js")'></script>
<script type="text/javascript" src='@Url.Content("~/dist/js/quicksight.js")'></script>
<script type="text/javascript">
    window.onload = () => embedDashboard('@(Html.Raw(Model.Url))');
</script>