"use strict";

// Generic local (non-QuickSight) visualization renderer. Draws a C3 chart from the
// payload produced by AMCOS.Logic.ViewModels.VisualizationViewModel.DataJson:
//   { chartType, xLabel, yLabel, stacked, valueFormat, categories:[...], series:[{name,values:[...]}] }
// Supports category charts (bar/line/spline/area/area-spline/step/scatter) and pie/donut.
// Safe to call with empty data — it simply renders nothing.
function renderLocalVisualization(elementId, viz) {
    var el = document.getElementById(elementId);
    if (!el || !viz) return;

    var categories = viz.categories || [];
    var series = viz.series || [];
    if (!series.length) return; // nothing to draw; the server shows an empty-state message

    var type = viz.chartType || "bar";
    var fmt = viz.valueFormat && window.d3 ? d3.format(viz.valueFormat) : null;
    var valueTooltip = fmt ? { format: { value: function (v) { return fmt(v); } } } : {};

    if (type === "pie" || type === "donut") {
        var pieColumns = [];
        if (series.length === 1) {
            // One series across categories -> each category becomes a slice.
            categories.forEach(function (c, i) { pieColumns.push([c, (series[0].values || [])[i] || 0]); });
        } else {
            // Multiple series -> one slice per series (first value).
            series.forEach(function (s) { pieColumns.push([s.name, (s.values || [])[0] || 0]); });
        }
        c3.generate({
            bindto: "#" + elementId,
            data: { columns: pieColumns, type: type },
            tooltip: valueTooltip
        });
        return;
    }

    // Category chart: x axis = categories, one column per series.
    var columns = [["x"].concat(categories)];
    series.forEach(function (s) { columns.push([s.name].concat(s.values || [])); });

    var groups = viz.stacked ? [series.map(function (s) { return s.name; })] : [];

    c3.generate({
        bindto: "#" + elementId,
        data: { x: "x", columns: columns, type: type, groups: groups },
        axis: {
            x: {
                type: "category",
                label: viz.xLabel ? { text: viz.xLabel, position: "outer-center" } : undefined
            },
            y: {
                label: viz.yLabel ? { text: viz.yLabel, position: "outer-middle" } : undefined,
                tick: fmt ? { format: fmt } : undefined
            }
        },
        grid: { y: { show: true } },
        tooltip: valueTooltip
    });
}
