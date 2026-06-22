using System.Text.Json.Serialization;

namespace AMCOS.Web.Core.Models;

public class AmcosLiteRequest
{
    [JsonPropertyName("userId")]
    public string? UserId { get; set; }

    [JsonPropertyName("pageElement")]
    public string? PageElement { get; set; }

    [JsonPropertyName("payPlan")]
    public string? PayPlan { get; set; }

    [JsonPropertyName("costSummaryName")]
    public string? CostSummaryName { get; set; }

    [JsonPropertyName("categoryGroupCode")]
    public string? CategoryGroupCode { get; set; }

    [JsonPropertyName("categorySubgroupCode")]
    public string? CategorySubgroupCode { get; set; }

    [JsonPropertyName("careerProgramNumber")]
    public string? CareerProgramNumber { get; set; }

    [JsonPropertyName("locationId")]
    public int LocationId { get; set; }

    [JsonPropertyName("locationText")]
    public string? LocationText { get; set; }

    [JsonPropertyName("scienceTechnologyReinventionLaboratory")]
    public string? ScienceTechnologyReinventionLaboratory { get; set; }

    [JsonPropertyName("dependentStatus")]
    public string? DependentStatus { get; set; }

    [JsonPropertyName("numberOfDependents")]
    public int NumberOfDependents { get; set; }

    [JsonPropertyName("overheadPercent")]
    public string? OverheadPercent { get; set; }

    [JsonPropertyName("inflationConversionType")]
    public string? InflationConversionType { get; set; }

    [JsonPropertyName("inflationYear")]
    public string? InflationYear { get; set; }
}

public class LiteCostRequest
{
    public string? PayPlan { get; set; }
    public string? CostSummaryName { get; set; }
    public string? CategoryGroupCode { get; set; }
    public string? CategorySubgroupCode { get; set; }
    public string? CareerProgramNumber { get; set; }
    public int LocationId { get; set; }
    public string? LocationText { get; set; }
    public string? ScienceTechnologyReinventionLaboratory { get; set; }
    public string? DependentStatus { get; set; }
    public int NumberOfDependents { get; set; }
    public float? OverheadPercent { get; set; }
    public string? InflationConversionType { get; set; }
    public string? InflationYear { get; set; }
}

public class ProjectAddUnitRequest
{
    [JsonPropertyName("userId")]
    public string? UserId { get; set; }

    [JsonPropertyName("categoryId")]
    public string? CategoryId { get; set; }

    [JsonPropertyName("pageElement")]
    public string? PageElement { get; set; }

    [JsonPropertyName("uic")]
    public string? Uic { get; set; }

    [JsonPropertyName("excludedPayPlans")]
    public string? ExcludedPayPlans { get; set; }

    [JsonPropertyName("dataAction")]
    public string? DataAction { get; set; }

    [JsonPropertyName("unitDataAction")]
    public string? UnitDataAction { get; set; }

    [JsonPropertyName("newSubprojectName")]
    public string? NewSubprojectName { get; set; }

    [JsonPropertyName("unitLocation")]
    public string? UnitLocation { get; set; }

    [JsonPropertyName("mtoeProjectInventoryYear")]
    public string? MtoeProjectInventoryYear { get; set; }

    [JsonPropertyName("projectExtendsSacsYears")]
    public string? ProjectExtendsSacsYears { get; set; }

    [JsonPropertyName("contractorOverheadPercent")]
    public string? ContractorOverheadPercent { get; set; }

    [JsonPropertyName("unitContractorOverheadPercent")]
    public string? UnitContractorOverheadPercent { get; set; }
}
