

-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE PROCEDURE [web].[GetPayPlanCrosswalkAE]
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
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 1
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V1,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 2
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V2,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V4,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 10
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V10,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 22
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V22,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 32
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V32,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 83
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V83,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 3966
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V3966,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 45
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V45,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 55
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V55,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 48
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V48,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 53
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V53,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 65
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V65,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 17
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V17,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 75
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V75,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 80
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V80,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 100
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V100,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 119
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V119,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 74
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V74,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 774
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V774,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 775
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V775,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 773
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V773,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 777
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V777,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 778
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V778,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 780
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V780,
        (
            SELECT SUM(Amount)
            FROM data.Costs
            WHERE PayPlan = 'AE'
                  AND CategorySubgroupCode = @categorySubgroupCode
                  AND GradeLevel = @gradeLevel
                  AND CostElementId = 4212
                  AND AmcosVersionId = @amcosVersionId
                  AND LocationId = -1
        ) AS V4212;
END;