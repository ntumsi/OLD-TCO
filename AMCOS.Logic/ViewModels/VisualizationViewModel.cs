using System.Collections.Generic;
using AMCOS.Data.Entities;
using AMCOS.Logic.Models;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace AMCOS.Logic.ViewModels
{
    /// <summary>
    /// Generic, local (non-QuickSight) visualization view model. A controller sets the
    /// <see cref="Title"/> plus the chart configuration and data (<see cref="Categories"/> +
    /// <see cref="Series"/> and/or a <see cref="TableColumns"/>/<see cref="TableRows"/> grid);
    /// the shared <c>_LocalVisualization</c> view renders a C3 chart and a data table from it.
    ///
    /// Everything defaults to empty, so a visualization can be scaffolded now (title + chart
    /// type) and wired to real data later — the view shows an empty state until data is set.
    /// </summary>
    public class VisualizationViewModel : BaseViewModel, IModel
    {
        /// <summary>Local visualization: renders the C3 chart + table via <c>_LocalVisualization</c>.</summary>
        public VisualizationViewModel(AMCOSUser user, string title)
            : this(user, title, "_LocalVisualization")
        {
        }

        /// <summary>Local visualization with an explicit partial name.</summary>
        public VisualizationViewModel(AMCOSUser user, string title, string view) : base(user)
        {
            Title = title;
            View = view;
        }

        /// <summary>
        /// Back-compat constructor for a legacy QuickSight embed (url + "_QuickSight" view).
        /// Retained so any not-yet-migrated call site keeps compiling; new work should use the
        /// local-visualization constructors above.
        /// </summary>
        public VisualizationViewModel(AMCOSUser user, string url, string title, string view) : base(user)
        {
            Url = url;
            Title = title;
            View = view;
        }

        public string Title { get; set; }

        /// <summary>Partial view to render — "_LocalVisualization" (default) or legacy "_QuickSight".</summary>
        public string View { get; set; }

        /// <summary>Optional legacy QuickSight embed URL (only used by the "_QuickSight" view).</summary>
        public string Url { get; set; }

        /// <summary>Optional descriptive blurb shown under the title.</summary>
        public string Description { get; set; }

        // ---- Chart configuration (C3) ------------------------------------------

        /// <summary>C3 chart type: bar, line, spline, area, area-spline, pie, donut, scatter, step.</summary>
        public string ChartType { get; set; } = "bar";

        public string XLabel { get; set; }
        public string YLabel { get; set; }

        /// <summary>Stack the series (bar/area) rather than group them side by side.</summary>
        public bool Stacked { get; set; }

        /// <summary>Optional d3 value format for axis ticks/tooltips, e.g. "$,.0f" or ",.0f" or ".2%".</summary>
        public string ValueFormat { get; set; }

        // ---- Chart data --------------------------------------------------------

        /// <summary>Category-axis labels (x). One entry per point; each series aligns to these.</summary>
        public List<string> Categories { get; set; } = new List<string>();

        /// <summary>One or more named data series, each aligned to <see cref="Categories"/>.</summary>
        public List<VisualizationSeries> Series { get; set; } = new List<VisualizationSeries>();

        // ---- Optional tabular view of the same data ----------------------------

        public List<string> TableColumns { get; set; } = new List<string>();
        public List<List<object>> TableRows { get; set; } = new List<List<object>>();

        /// <summary>True when there is anything to render (chart series or table rows).</summary>
        public bool HasData =>
            (Categories.Count > 0 && Series.Count > 0) || TableRows.Count > 0;

        /// <summary>
        /// Chart payload serialized for the client-side C3 renderer (dist/js/local-visualization.js).
        /// camelCase so the JS reads series[].name / series[].values — avoids the PascalCase/camelCase
        /// mismatch that has bitten other ported JSON in this app.
        /// </summary>
        public string DataJson => JsonConvert.SerializeObject(
            new
            {
                chartType = ChartType,
                xLabel = XLabel,
                yLabel = YLabel,
                stacked = Stacked,
                valueFormat = ValueFormat,
                categories = Categories,
                series = Series
            },
            new JsonSerializerSettings { ContractResolver = new CamelCasePropertyNamesContractResolver() });

        // ---- Fluent helpers (keep controller actions terse) --------------------

        public VisualizationViewModel AsChart(string chartType, string xLabel = null, string yLabel = null)
        {
            ChartType = chartType;
            XLabel = xLabel;
            YLabel = yLabel;
            return this;
        }

        public VisualizationViewModel WithSeries(string name, params double[] values)
        {
            Series.Add(new VisualizationSeries(name, values));
            return this;
        }
    }

    /// <summary>A single named data series whose values align to the chart's Categories.</summary>
    public class VisualizationSeries
    {
        public VisualizationSeries()
        {
        }

        public VisualizationSeries(string name, IEnumerable<double> values)
        {
            Name = name;
            Values = new List<double>(values);
        }

        public string Name { get; set; }
        public List<double> Values { get; set; } = new List<double>();
    }
}
