CREATE PROC [warehouse].[PopulateCategory]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    TRUNCATE TABLE warehouse.Category;

    INSERT INTO warehouse.Category
    (
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategoryGroupDisplay,
        CategorySubgroupCode,
        CategorySubgroupDescription,
        CategorySubgroupDisplay,
        CareerProgramNumber,
        CareerProgramDescription,
        CareerProgramDisplay
    )
    SELECT PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           NULL AS CategoryGroupDisplay,
           CategorySubgroupCode,
           NULL AS CategorySubgroupDescription,
           NULL AS CategorySubgroupDisplay,
           CareerProgramNumber,
           NULL AS CareerProgramDescription,
           NULL AS CareerProgramDisplay
    FROM data.Costs
    WHERE AmcosVersionId = @AmcosVersionId
          AND
          (
              (
                  CategoryGroupCode = '-1'
                  AND CategorySubgroupCode = '-1'
                  AND CareerProgramNumber <> '-1'
              )
              OR
              (
                  CategoryGroupCode <> '-1'
                  AND CategorySubgroupCode <> '-1'
                  AND CareerProgramNumber = '-1'
              )
          )
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             CareerProgramNumber;

    UPDATE warehouse.Category
    SET CategoryGroupDescription = CategorySubgroup.CategoryGroupDescription,
        CategoryGroupDisplay = CategorySubgroup.CategoryGroupCode + ' - ' + CategorySubgroup.CategoryGroupDescription,
        CategorySubgroupDescription = CategorySubgroup.CategorySubgroupDescription,
        CategorySubgroupDisplay = CategorySubgroup.CategorySubgroupCode + ' - '
                                  + CategorySubgroup.CategorySubgroupDescription
    FROM data.CategorySubgroup CategorySubgroup
        INNER JOIN warehouse.Category Category
            ON Category.PayPlan = CategorySubgroup.PayPlan
               AND Category.CategoryGroupCode = CategorySubgroup.CategoryGroupCode
               AND Category.CategorySubgroupCode = CategorySubgroup.CategorySubgroupCode;

    UPDATE warehouse.Category
    SET CareerProgramDescription = ArmyCareerProgram.Title,
        CareerProgramDisplay = 'CP ' + ArmyCareerProgram.CareerProgramNumber + ' - ' + ArmyCareerProgram.Title
    FROM lookup.ArmyCareerProgram ArmyCareerProgram
        INNER JOIN warehouse.Category Category
            ON Category.CareerProgramNumber = ArmyCareerProgram.CareerProgramNumber
    WHERE @AmcosVersionId
    BETWEEN ArmyCareerProgram.AmcosVersionIdStart AND ArmyCareerProgram.AmcosVersionIdEnd;

    INSERT INTO warehouse.Category
    (
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategoryGroupDisplay,
        CategorySubgroupCode,
        CategorySubgroupDescription,
        CategorySubgroupDisplay,
        CareerProgramNumber,
        CareerProgramDescription,
        CareerProgramDisplay
    )
    SELECT 'CCE' AS PayPlan,
           SUBSTRING(OES.SOC, 1, 2) + '-0000' AS CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           NULL AS CategoryGroupDisplay,
           OES.SOC AS CategorySubgroupCode,
           LTRIM(SOC.OccupationTitle) AS CategorySubgroupDescription,
           OES.SOC + ' - ' + LTRIM(SOC.OccupationTitle) AS CategorySubgroupDisplay,
           '-1' AS CareerProgramNumber,
           NULL AS CareerProgramDescription,
           NULL AS CareerProgramDisplay
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro OES
        INNER JOIN lookup.SOCStructure SOC
            ON SOC.OccupationCode = OES.SOC
    WHERE SOC.GroupLevel = 'Detailed'
          AND @AmcosVersionId
          BETWEEN SOC.AmcosVersionIdStart AND SOC.AmcosVersionIdEnd
          AND OES.AmcosVersionId = @AmcosVersionId
    GROUP BY OES.SOC,
             SOC.OccupationTitle;

    UPDATE warehouse.Category
    SET CategoryGroupDescription = SOC.OccupationTitle,
        CategoryGroupDisplay = Category.CategoryGroupCode + ' - ' + SOC.OccupationTitle
    FROM warehouse.Category Category
        INNER JOIN lookup.SOCStructure SOC
            ON Category.CategoryGroupCode = SOC.OccupationCode
    WHERE Category.PayPlan = 'CCE'
          AND SOC.GroupLevel = 'Major'
          AND Category.CategoryGroupDescription IS NULL
          AND Category.CategoryGroupDisplay IS NULL;

END;