


-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE PROCEDURE [web].[GetPayPlanCrosswalkAO]
(
    @categorySubgroupCode NVARCHAR(5),
    @gradeLevel TINYINT,
    @amcosVersionId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 128
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V128,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 129
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V129,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 131
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V131,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 136
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V136,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 145
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V145,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 151
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V151,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 180
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V180,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 154
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V154,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 162
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V162,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 157
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V157,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 161
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V161,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 167
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V167,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 150
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V150,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 174
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V174,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 177
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V177,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 188
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V188,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 198
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V198,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 173
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V173,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 790
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V790,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 791
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V791,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 789
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V789,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 793
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V793,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 794
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V794,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 796
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V796,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4213
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V4213;
END;