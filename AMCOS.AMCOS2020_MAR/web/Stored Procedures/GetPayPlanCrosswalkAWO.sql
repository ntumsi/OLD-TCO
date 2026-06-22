


-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE PROCEDURE [web].[GetPayPlanCrosswalkAWO]
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
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 204
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V204,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 205
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V205,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 207
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V207,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 210
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V210,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 219
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V219,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 225
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V225,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 245
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V245,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 228
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V228,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 236
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V236,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 231
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V231,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 235
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V235,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 241
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V241,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 224
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V224,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 248
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V248,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 678
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V678,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 256
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V256,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 682
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V682,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 269
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V269,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 247
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V247,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 806
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V806,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 807
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V807,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 805
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V805,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 809
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V809,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 810
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V810,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 812
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V812,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AWO'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4214
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V4214;
END;