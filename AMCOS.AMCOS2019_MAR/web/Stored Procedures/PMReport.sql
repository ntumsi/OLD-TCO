
CREATE PROCEDURE [web].[PMReport]
(
    @UserId NVARCHAR(50),
    @ProjectId INT,
    @Fields NVARCHAR(500)
)
AS
BEGIN

    DECLARE @AvgCostOfBenefits INTEGER = dbo.GetCostElementId('CCE', 'Contractor', 'Avg Cost of Benefits');
    DECLARE @AvgCostOfSalary INTEGER = dbo.GetCostElementId('CCE', 'Contractor', 'Avg Cost of Salary');
    DECLARE @AvgCostOfOverhead INTEGER = dbo.GetCostElementId('CCE', 'Contractor', 'Avg Cost of Overhead');

    DECLARE @ProjectStartYear INT;

    SELECT @ProjectStartYear = YearStart
    FROM webuser.PMProject
    WHERE ProjectId = @ProjectId;

    CREATE TABLE #tblCosts
    (
        PMCategoryName NVARCHAR(200) NULL,
        [Year] INT NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(7) NULL,
        CategoryGroupDescription NVARCHAR(250) NULL,
        CategorySubgroupCode NVARCHAR(7) NULL,
        CategorySubGroupDescription NVARCHAR(255) NULL,
        MetroArea NVARCHAR(150) NULL,
        LocalityId INT NULL,
        LocalityPayArea NVARCHAR(100) NULL,
        StateCountry NVARCHAR(50) NULL,
        FunctionalArea NVARCHAR(250) NULL,
        CostCenter NVARCHAR(250) NULL,
        Grade NVARCHAR(80) NULL,
        Summary NVARCHAR(200) NULL,
        APPN NVARCHAR(100) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        CostElementName NVARCHAR(300) NULL,
        CostElementId INT NULL,
        Inventory INT NULL,
        Cost FLOAT NULL,
        ExceedsCCESalaryLimit TINYINT NULL
    );


    /* Insert costs where CategoryGroupCode = '__ALL__' and CategorySubgroupCode = '__ALL__' */
    INSERT INTO #tblCosts
    (
        PMCategoryName,
        [Year],
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubGroupDescription,
        MetroArea,
        LocalityId,
        LocalityPayArea,
        FunctionalArea,
        CostCenter,
        Grade,
        Summary,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        Inventory,
        Cost
    )
    SELECT PMCategoryName,
           [Year],
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubGroupCode,
           NULL AS CategorySubGroupDescription,
           AreaCode,
           LocalityId,
           NULL AS LocalityPayArea,
           NULL AS FunctionalArea,
           NULL AS CostCenter,
           GradeLevel,
           Summary,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Inventory,
           Cost
    FROM web.PMReportAllAll(@UserId, @ProjectId);

    /* Insert costs where CategoryGroupCode != '__ALL__' and CategorySubgroupCode = '__ALL__' */
    INSERT INTO #tblCosts
    (
        PMCategoryName,
        [Year],
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubGroupDescription,
        MetroArea,
        LocalityId,
        LocalityPayArea,
        FunctionalArea,
        CostCenter,
        Grade,
        Summary,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        Inventory,
        Cost
    )
    SELECT PMCategoryName,
           [Year],
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubGroupCode,
           NULL AS CategorySubGroupDescription,
           AreaCode,
           LocalityId,
           NULL AS LocalityPayArea,
           NULL AS FunctionalArea,
           NULL AS CostCenter,
           GradeLevel,
           Summary,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Inventory,
           Cost
    FROM web.PMReportCategorySubGroupCodeAll(@UserId, @ProjectId) p1;

    /* Insert costs where CategoryGroupCode != '__ALL__' and CategorySubgroupCode != '__ALL__' */
    INSERT INTO #tblCosts
    (
        PMCategoryName,
        [Year],
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubGroupDescription,
        MetroArea,
        LocalityId,
        LocalityPayArea,
        FunctionalArea,
        CostCenter,
        Grade,
        Summary,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        Inventory,
        Cost
    )
    SELECT PMCategoryName,
           [Year],
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubGroupCode,
           NULL AS CategorySubGroupDescription,
           AreaCode,
           LocalityId,
           NULL AS LocalityPayArea,
           NULL AS FunctionalArea,
           NULL AS CostCenter,
           GradeLevel,
           Summary,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Inventory,
           Cost
    FROM web.PMReportCategorySubGroupCodeNotAll(@UserId, @ProjectId);

    /* CCE */
    DECLARE @BenefitRatio NUMERIC(18, 4);

    SELECT @BenefitRatio = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'CCE'
          AND paramName = 'Benefits_All';

    CREATE TABLE #CostCCE
    (
        PMCategoryName NVARCHAR(200) NOT NULL,
        [Year] INT NOT NULL,
        PayPlan NVARCHAR(3) NOT NULL,
        CategoryGroupCode NVARCHAR(800) NOT NULL,
        CategorySubgroupCode NVARCHAR(800) NOT NULL,
        Area NVARCHAR(500) NOT NULL,
        Locality NVARCHAR(100) NOT NULL,
        Grade NVARCHAR(10) NOT NULL,
        Summary NVARCHAR(200) NOT NULL,
        APPN NVARCHAR(100) NOT NULL,
        CostElementName NVARCHAR(300) NOT NULL,
        CostElementId INT NOT NULL,
        Inv INT NOT NULL,
        Cost FLOAT NOT NULL,
        CostElementCategory NVARCHAR(50) NOT NULL,
        ExceedsCCESalaryLimit TINYINT NOT NULL
    );

    INSERT INTO #CostCCE
    (
        PMCategoryName,
        Year,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        Area,
        Locality,
        Grade,
        Summary,
        APPN,
        CostElementName,
        CostElementId,
        Inv,
        Cost,
        CostElementCategory,
        ExceedsCCESalaryLimit
    )
    SELECT CategoryName,
           Year,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           Area,
           Locality,
           Grade,
           Summary,
           APPN,
           CostElementName,
           CostElementId,
           Inv,
           Cost,
           CostElementCategory,
           ExceedsSalaryLimit
    FROM web.PMReportCCEAvgCostOfSalary(@UserId, @ProjectId);

    INSERT INTO #CostCCE
    SELECT PMCategoryName,
           [Year],
           'CCE',
           CategoryGroupCode,
           CategorySubgroupCode,
           Area,
           Locality,
           Grade,
           Summary,
           APPN,
           'Avg Cost of Benefits' AS CostElementName,
           @AvgCostOfBenefits AS CostElementId,
           Inv,
           Cost * @BenefitRatio,
           'Compensation',
           ExceedsCCESalaryLimit
    FROM #CostCCE
    WHERE CostElementId = @AvgCostOfSalary;

    INSERT INTO #CostCCE
    (
        PMCategoryName,
        Year,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        Area,
        Locality,
        Grade,
        Summary,
        APPN,
        CostElementName,
        CostElementId,
        Inv,
        Cost,
        CostElementCategory,
        ExceedsCCESalaryLimit
    )
    SELECT a.PMCategoryName,
           a.[Year],
           'CCE',
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.Area,
           a.Locality,
           a.Grade,
           a.Summary,
           a.APPN,
           'Avg Cost of Overhead' AS CostElementName,
           @AvgCostOfOverhead AS CostElementId,
           a.Inv,
           a.Cost * b.overheadPct / 100,
           'Overhead',
           a.ExceedsCCESalaryLimit
    FROM #CostCCE a
        JOIN webuser.PMCategorySkill b
            ON a.CategoryGroupCode = b.CategoryGroupCode
               AND a.[CategorySubgroupCode] = b.CategorySubGroupCode
    WHERE a.CostElementId = @AvgCostOfSalary
          AND b.ProjectId = @ProjectId
          AND
          (
              (
                  a.Grade = 'A_PCT10'
                  AND b.GradeLevel = 1
              )
              OR
              (
                  a.Grade = 'A_PCT25'
                  AND b.GradeLevel = 2
              )
              OR
              (
                  a.Grade = 'A_MEDIAN'
                  AND b.GradeLevel = 3
              )
              OR
              (
                  a.Grade = 'A_PCT75'
                  AND b.GradeLevel = 4
              )
              OR
              (
                  a.Grade = 'A_PCT90'
                  AND b.GradeLevel = 5
              )
          );

    INSERT INTO #tblCosts
    (
        PMCategoryName,
        [Year],
        PayPlan,
        CategoryGroupCode,
        CategoryGroupDescription,
        CategorySubgroupCode,
        CategorySubGroupDescription,
        MetroArea,
        LocalityId,
        LocalityPayArea,
        FunctionalArea,
        CostCenter,
        Grade,
        Summary,
        APPN,
        CostElementName,
        CostElementId,
        Inventory,
        Cost,
        CostElementCategory,
        ExceedsCCESalaryLimit
    )
    SELECT PMCategoryName,
           [Year],
           PayPlan,
           CategoryGroupCode,
           NULL AS CategoryGroupDescription,
           CategorySubgroupCode,
           NULL AS CategorySubGroupDescription,
           Area,
           Locality,
           NULL AS LocalityPayArea,
           '' AS FunctionalAreaCode,
           '' AS CostCenterCode,
           Grade,
           Summary,
           APPN,
           CostElementName,
           CostElementId,
           Inv,
           Cost,
           CostElementCategory,
           ExceedsCCESalaryLimit
    FROM #CostCCE;


    /* DB, DE, DJ, DK, GP, NH, NJ, NK Costs */
    INSERT INTO #tblCosts
    (
        PMCategoryName,
        Year,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        MetroArea,
        LocalityId,
        StateCountry,
        FunctionalArea,
        CostCenter,
        Grade,
        Summary,
        APPN,
        CostElementCategory,
        CostElementName,
        CostElementId,
        Inventory,
        Cost
    )
    SELECT GFEBS.PMCategoryName,
           GFEBS.[Year],
           GFEBS.PayPlan,
           GFEBS.CategoryGroupCode,
           GFEBS.CategorySubGroupCode,
           GFEBS.AreaCode,
           GFEBS.LocalityId,
           GFEBS.StateCountry,
           FunctionalArea.FunctionalAreaText + ' (' + GFEBS.FunctionalAreaCode + ')' AS FunctionalArea,
           CostCenter.CostCenterText + ' (' + GFEBS.CostCenterCode + ')' AS CostCenter,
           GFEBS.GradeLevel,
           GFEBS.Summary,
           GFEBS.APPN,
           GFEBS.CostElementCategory,
           GFEBS.CostElementName,
           GFEBS.CostElementId,
           GFEBS.Inventory,
           GFEBS.Cost
    FROM web.PMReportGFEBS(@UserId, @ProjectId) GFEBS
        LEFT JOIN lookup.GFEBS_FunctionalArea FunctionalArea
            ON FunctionalArea.FunctionalAreaCode = GFEBS.FunctionalAreaCode
        LEFT JOIN lookup.GFEBS_CostCenter CostCenter
            ON CostCenter.CostCenterCode = GFEBS.CostCenterCode;

    /* 3/2/2013 Gary temp replace this particular APPN value for proper sorting purpose.  'MMPA' will be replaced to 'PA' in ASP.Net code */
    UPDATE #tblCosts
    SET APPN = REPLACE(APPN, ' PA', ' MMPA')
    WHERE APPN LIKE '% PA%';

    UPDATE #tblCosts
    SET CostElementName = 'CCE_1Avg Cost of Salary'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Salary';

    UPDATE #tblCosts
    SET CostElementName = 'CCE_2Avg Cost of Benefits'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Benefits';

    UPDATE #tblCosts
    SET CostElementName = 'CCE_3Avg Cost of Overhead'
    WHERE PayPlan = 'CCE'
          AND CostElementName = 'Avg Cost of Overhead';

    UPDATE a
    SET a.LocalityPayArea = b.[Description] + ', @ ' + CONVERT(VARCHAR, (b.Amount - 1) * 100) + '%'
    FROM #tblCosts a
        JOIN lookup.LocalityRates b
            ON a.LocalityId = b.Id;

    UPDATE #tblCosts
    SET Grade = b.GradeType + tblCosts.Grade
    FROM #tblCosts tblCosts
        JOIN lookup.Grade b
            ON tblCosts.PayPlan = b.PayPlan;

    UPDATE a
    SET a.CategoryGroupDescription = a.CategoryGroupCode + ':' + b.CategoryGroupDescription,
        a.CategorySubGroupDescription = a.CategorySubgroupCode + ':' + b.CategorySubGroupDescription,
        a.MetroArea = a.MetroArea + ':' + User_Categories.AreaName
    FROM #tblCosts a
        JOIN data.CategorySubgroup b
            ON a.PayPlan = b.PayPlan
               AND a.CategorySubgroupCode = b.CategorySubGroupCode
        LEFT JOIN lookup.MetroArea User_Categories
            ON a.MetroArea = User_Categories.AreaCode;

    UPDATE #tblCosts
    SET CategoryGroupDescription = CategoryGroupCode
    WHERE CategoryGroupCode = 'ALL';

    UPDATE #tblCosts
    SET CategorySubGroupDescription = CategorySubgroupCode
    WHERE CategorySubgroupCode = 'ALL';

    UPDATE #tblCosts
    SET CategorySubGroupDescription = '0602 : Medical Officer Series'
    WHERE CategorySubgroupCode = '0602';

    UPDATE #tblCosts
    SET CategorySubGroupDescription = '0680 : Dental Officer Series'
    WHERE CategorySubgroupCode = '0680';

    SELECT PMCategoryName,
           Year,
           PayPlan,
           CategoryGroupCode,
           CategoryGroupDescription,
           CategorySubgroupCode,
           CategorySubGroupDescription,
           MetroArea,
           LocalityId,
           LocalityPayArea,
           StateCountry,
           FunctionalArea,
           CostCenter,
           Grade,
           Summary,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Inventory,
           Cost,
           ExceedsCCESalaryLimit
    INTO #CostDefault
    FROM #tblCosts
    WHERE Summary = 'Default';

    SELECT PMCategoryName,
           Year,
           PayPlan,
           CategoryGroupCode,
           CategoryGroupDescription,
           CategorySubgroupCode,
           CategorySubGroupDescription,
           MetroArea,
           LocalityId,
           LocalityPayArea,
           StateCountry,
           FunctionalArea,
           CostCenter,
           Grade,
           Summary,
           APPN,
           CostElementCategory,
           CostElementName,
           CostElementId,
           Inventory,
           Cost,
           ExceedsCCESalaryLimit
    INTO #tblCostOsdCapeDodi
    FROM #tblCosts
    WHERE Summary <> 'Default';

    DECLARE @sSQL VARCHAR(6000);
    SET @sSQL
        = 'SELECT [Year]+' + CONVERT(VARCHAR, @ProjectStartYear) + ' as Year, ' + @Fields
          + ' , ROUND(ISNULL(Cost,0),2) As Cost FROM #CostDefault';
    EXEC dbo.spCrossTabNumber @table = @sSQL,      -- varchar(8000)
                              @onrows = @Fields,   -- varchar(2000)
                              @onrowsalias = NULL, -- varchar(2000)
                              @oncols = '[Year]',  -- varchar(2000)
                              @sumcol = 'Cost';    -- varchar(2000)


    SET @sSQL
        = 'SELECT [Year]+' + CONVERT(VARCHAR, @ProjectStartYear) + ' as Year, ' + @Fields
          + ' , ROUND(ISNULL(Cost,0),2) As Cost FROM #tblCostOsdCapeDodi';
    EXEC dbo.spCrossTabNumber @table = @sSQL,      -- varchar(8000)
                              @onrows = @Fields,   -- varchar(2000)
                              @onrowsalias = NULL, -- varchar(2000)
                              @oncols = '[Year]',  -- varchar(2000)
                              @sumcol = 'Cost';    -- varchar(2000)


    SELECT 208000,
           @BenefitRatio,
           ISNULL(
           (
               SELECT MIN(overheadPct)
               FROM webuser.PMCategorySkill
               WHERE ProjectId = @ProjectId
                     AND PayPlan = 'CCE'
           ),
           0
                 ) AS minOverheadPct,
           (
               SELECT COUNT(*) FROM #CostCCE WHERE Cost < 0
           ) AS coutOfOverLimitRows;
    DROP TABLE #CostDefault;
    DROP TABLE #tblCostOsdCapeDodi;
    DROP TABLE #tblCosts;
    DROP TABLE #CostCCE;
    RETURN;
END;