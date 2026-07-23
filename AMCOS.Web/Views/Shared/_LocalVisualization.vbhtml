@ModelType AMCOS.Logic.ViewModels.VisualizationViewModel
@*
    Generic local visualization partial (replaces _QuickSight). Renders a C3 chart and an
    optional data table from VisualizationViewModel. Populate Categories/Series (and/or the
    table) in the controller action; until then it shows an empty state.
*@

<div class="local-visualization">
    @If Not String.IsNullOrWhiteSpace(Model.Description) Then
        @<p class="text-muted">@Model.Description</p>
    End If

    @If Not Model.HasData Then
        @<div class="alert alert-info">
            This visualization is scaffolded but has no data yet. Set <code>Categories</code> and
            <code>Series</code> (or <code>TableColumns</code>/<code>TableRows</code>) in the controller
            action to render the <strong>@Model.Title</strong> chart.
        </div>
    End If

    <div id="localVizChart" style="min-height: 420px;"></div>

    @If Model.TableColumns IsNot Nothing AndAlso Model.TableColumns.Count > 0 Then
        @<div class="table-responsive mt-3">
            <table class="table table-sm table-striped">
                <thead>
                    <tr>
                        @For Each col In Model.TableColumns
                            @<th>@col</th>
                        Next
                    </tr>
                </thead>
                <tbody>
                    @For Each row In Model.TableRows
                        @<tr>
                            @For Each cell In row
                                @<td>@cell</td>
                            Next
                        </tr>
                    Next
                </tbody>
            </table>
        </div>
    End If
</div>

<script type="text/javascript" src='@Url.Content("~/dist/js/d3.min.js")'></script>
<script type="text/javascript" src='@Url.Content("~/dist/js/c3.min.js")'></script>
<script type="text/javascript" src='@Url.Content("~/dist/js/local-visualization.js")'></script>
<script type="text/javascript">
    (function () {
        var viz = @Html.Raw(Model.DataJson);
        renderLocalVisualization("localVizChart", viz);
    })();
</script>
