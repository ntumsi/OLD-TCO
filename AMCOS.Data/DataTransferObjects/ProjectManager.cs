namespace AMCOS.Data.DataTransferObjects
{
    public class CategoryListDto
    {
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public string ProjectName { get; set; }
        public int CategoryId { get; set; }
        public string CategoryName { get; set; }
    }
    public class MtoeUnitYearDto
    {
        public string Value { get; set; }
        public string Text { get; set; }
    }
    public class ProjectListDto
    {
        public string ProjectName { get; set; }
        public int ProjectId { get; set; }
    }
    public class ProjectListWithDescriptionDto
    {
        public string ProjectName { get; set; }
        public string Description { get; set; }
    }
    public class ProjectRequirementListDto
    {
        public string UserId { get; set; }
        public int ProjectId { get; set; }
        public string CategoryName { get; set; }
        public int CategoryId { get; set; }
        public int SkillId { get; set; }
        public string Uic { get; set; }
        public string PayPlan { get; set; }
        public string CategoryGroupCode { get; set; }
        public string CategorySubgroupCode { get; set; }
        public string CareerProgramNumber { get; set; }
        public int LocationId { get; set; }
        public string Location { get; set; }
        public string STRL { get; set; }
        public string Grade { get; set; }
        public string DependentStatus { get; set; }
        public string NumberOfDependents { get; set; }
        public string ActiveDutyDays { get; set; }
        public string OverheadPercent { get; set; }
        public int Year { get; set; }
        public int Amount { get; set; }
    }
    public class ProjectOutputListDto
    {
        public int CategoryId { get; set; }
        public string Category { get; set; }
        public string PayPlan { get; set; }
    }
    public class UnitDto
    {
        public string Value { get; set; }
        public string Text { get; set; }
    }
    public class UnitLocationDto
    {
        public string UIC { get; set; }
        public string PayPlan { get; set; }
        public string Location { get; set; }
    }
    public class UnitDetailsDto
    {
        public string UIC { get; set; }
        public string UnitYear { get; set; }
        public string AsOf { get; set; }
        public string AuthorizationDocument { get; set; }
    }
    public class UnitPersonnelDto
    {
        public string UIC { get; set; }
        public string PayPlan { get; set; }
        public int Inventory { get; set; }
    }
    public class UnitPersonnelAndLocationDto
    {
        public string UIC { get; set; }
        public string UnitYear { get; set; }
        public string AsOf { get; set; }
        public string AuthorizationDocument { get; set; }
        public string PayPlan { get; set; }
        public int Inventory { get; set; }
        public string Location { get; set; }
        public int NumUnitYears { get; set; }
    }
}
