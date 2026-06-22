

-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE PROCEDURE [web].[GetPayPlanCrosswalkGS]
(
    @categorySubgroupCode NVARCHAR(5),
    @gradeLevel TINYINT,
    @LocationId INT,
    @amcosVersionId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 275
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V275,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 276
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V276,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 284
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V284,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 286
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V286,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 277
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V277,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 279
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V279,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 282
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V282,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 735
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V735,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 951
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V951,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 952
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V952,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4856
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4856,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4859
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4859,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4864
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4864,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4865
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4865,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4870
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4870,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4871
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4871,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4894
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4894,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'GS'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4895
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = @LocationId
        ) AS V4895;
END;