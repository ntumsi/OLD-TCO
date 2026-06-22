
-- =============================================
-- Author:Dan Hogan
-- Create date: 9/17/2019
-- Description:	Cost of Averages - compute the group and payplan averages

-- =============================================
CREATE PROCEDURE [crunch].[CostOfMilAverages]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;



    DROP TABLE IF EXISTS #SubgroupData;
    CREATE TABLE #SubgroupData
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeType NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        CostElementId INT NULL,
        CostElementName NVARCHAR(250) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        WeaponSystemId INT NULL,
        WeaponSystemName NVARCHAR(50) NULL,
        Appn NVARCHAR(25) NULL,
        Inventory INT NULL,
        Amount NUMERIC(26, 2) NULL,
        AmcosVersionId INT NULL,
        AmcosVersionIdStart INT NULL,
        AmcosVersionIdEnd INT NULL
    );

    INSERT INTO #SubgroupData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        CostElementId,
        CostElementName,
        CostElementCategory,
        WeaponSystemId,
        Appn,
        Inventory,
        AmcosVersionIdStart,
        AmcosVersionIdEnd,
        AmcosVersionId
    )

    -- get every combination of costs available
    SELECT a.PayPlan,
           b.GradeLevel,
           b.GradeType,
           b.CategoryGroupCode,
           b.CategorySubgroupCode,
           a.CostElementId,
           a.CostElementName,
           a.CostElementCategory,
           -1,
           a.APPN,
           b.Inventory,
           a.AmcosVersionIdStart,
           a.AmcosVersionIdEnd,
           b.AmcosVersionId
    FROM lookup.CostElement AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   GradeLevel,
                   GradeType,
                   SUM(Inventory) AS Inventory,
                   AmcosVersionId
            FROM data.KnownInventory
            WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                  AND AmcosVersionId = @AmcosVersionId
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     GradeLevel,
                     GradeType,
                     AmcosVersionId
        ) AS b
            ON a.PayPlan = b.PayPlan
    WHERE a.PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
          AND @AmcosVersionId
          BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
          AND a.CostElementName NOT LIKE '%Weapon Specific Training'; --we need a special cross join for these records


    --do another insert, this time with weapon system data
    INSERT INTO #SubgroupData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CategorySubgroupCode,
        CostElementId,
        CostElementName,
        CostElementCategory,
        WeaponSystemId,
        WeaponSystemName,
        Appn,
        Inventory,
        AmcosVersionIdStart,
        AmcosVersionIdEnd,
        AmcosVersionId
    )

    -- get every combination of costs available
    SELECT a.PayPlan,
           a.GradeLevel,
           a.GradeType,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.CostElementId,
           a.CostElementName,
           a.CostElementCategory,
           b.WeaponSystemId,
           b.WeaponSystemName,
           a.APPN,
           a.Inventory,
           a.AmcosVersionIdStart,
           a.AmcosVersionIdEnd,
           a.AmcosVersionId
    FROM
    (
        SELECT a.PayPlan,
               b.GradeLevel,
               b.GradeType,
               b.CategoryGroupCode,
               b.CategorySubgroupCode,
               a.CostElementId,
               a.CostElementName,
               a.CostElementCategory,
               a.APPN,
               b.Inventory,
               a.AmcosVersionIdStart,
               a.AmcosVersionIdEnd,
               b.AmcosVersionId
        FROM lookup.CostElement AS a
            INNER JOIN
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       GradeLevel,
                       GradeType,
                       SUM(Inventory) AS Inventory,
                       AmcosVersionId
                FROM data.KnownInventory
                WHERE PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                      AND AmcosVersionId = @AmcosVersionId
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         GradeLevel,
                         GradeType,
                         AmcosVersionId
            ) AS b
                ON a.PayPlan = b.PayPlan
        WHERE a.PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
              AND @AmcosVersionId
              BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
              AND a.CostElementName LIKE '%Weapon Specific Training'
    ) AS a
        CROSS JOIN lookup.WeaponSystem AS b
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    --bring in the cost data for active (no MHA)
    UPDATE #SubgroupData
    SET Amount = b.Amount
    FROM #SubgroupData AS a
        INNER JOIN
        (
            SELECT [PayPlan],
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   [CostElementId],
                   [GradeType],
                   [GradeLevel],
                   [WeaponSystemId],
                   [Amount],
                   [CrunchTime],
                   [AmcosVersionId]
            FROM data.Costs Costs
            WHERE AmcosVersionId = @AmcosVersionId
                  AND (Costs.LocationId = -1) --location specific data is not averaged
                  AND CategoryGroupCode <> '-1' --don't pull in any existing payplan avg costs
                  AND CategorySubgroupCode <> '-1' --don't pull in any existing group avg costs
                  AND PayPlan IN ( 'AE', 'AO', 'AWO', 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.GradeLevel = b.GradeLevel
               AND a.CostElementId = b.CostElementId
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.WeaponSystemId = b.WeaponSystemId;



    IF @Debug = 1
    BEGIN
        SELECT 'these records have no matching cost table records which may be correct or may not be';
        SELECT DISTINCT
               PayPlan,
               CostElementName,
               WeaponSystemName
        FROM #SubgroupData
        WHERE Amount IS NULL
        ORDER BY CostElementName,
                 WeaponSystemName,
                 PayPlan;
        --ORDER BY costelementcategory, costelementname, payplan, gradelevel, CategorySubgroupCode
        SELECT 'here is the entire combined table of values';
        SELECT *
        FROM #SubgroupData
        WHERE PayPlan = 'AE'
              AND CategoryGroupCode = '00'
              AND CostElementId IN
                  (
                      SELECT CostElementId
                      FROM lookup.CostSummaryElement AS a
                          INNER JOIN lookup.CostSummary AS b
                              ON a.SummaryId = b.SummaryId
                      WHERE Name = 'Default'
                  )
        ORDER BY PayPlan,
                 GradeLevel,
                 CategorySubgroupCode,
                 CostElementId;
    END;

    --when there are no corresponding records in the cost table their amounts show up as null
    --for a proper weighted average those costs need to be 0 so we make them so
    UPDATE #SubgroupData
    SET Amount = 0
    WHERE Amount IS NULL;

    DROP TABLE IF EXISTS #GroupData;
    CREATE TABLE #GroupData
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeType NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CostElementId INT NULL,
        CostElementName NVARCHAR(250) NULL,
        CostElementCategory NVARCHAR(50) NULL,
        WeaponSystemId INT NULL,
        WeaponSystemName NVARCHAR(50) NULL,
        Appn NVARCHAR(25) NULL,
        Inventory INT NULL,
        Amount NUMERIC(26, 2) NULL,
        AmcosVersionId INT NULL,
        AmcosVersionIdStart INT NULL,
        AmcosVersionIdEnd INT NULL
    );

    INSERT INTO #GroupData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CostElementId,
        CostElementName,
        CostElementCategory,
        WeaponSystemId,
        WeaponSystemName,
        Appn,
        Inventory,
        Amount,
        AmcosVersionIdStart,
        AmcosVersionIdEnd,
        AmcosVersionId
    )
    --to get group level data we just do a simple weighted average using inventory
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CostElementId,
           CostElementName,
           CostElementCategory,
           WeaponSystemId,
           WeaponSystemName,
           Appn,
           SUM(Inventory),
           SUM(Amount * Inventory) / SUM(Inventory),
           MAX(AmcosVersionIdStart),
           MAX(AmcosVersionIdEnd),
           MAX(AmcosVersionId)
    FROM #SubgroupData
    WHERE CostElementName NOT LIKE 'Actual%' --everything is averaged except actual costs
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CostElementId,
             CostElementName,
             CostElementCategory,
             Appn,
             WeaponSystemId,
             WeaponSystemName;


    INSERT INTO #GroupData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        CategoryGroupCode,
        CostElementId,
        CostElementName,
        CostElementCategory,
        WeaponSystemId,
        WeaponSystemName,
        Appn,
        Inventory,
        Amount,
        AmcosVersionIdStart,
        AmcosVersionIdEnd,
        AmcosVersionId
    )
    --to get group level data we just do a simple weighted average using inventory
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CategoryGroupCode,
           CostElementId,
           CostElementName,
           CostElementCategory,
           WeaponSystemId,
           WeaponSystemName,
           Appn,
           SUM(Inventory),
           SUM(Amount),
           MAX(AmcosVersionIdStart),
           MAX(AmcosVersionIdEnd),
           MAX(AmcosVersionId)
    FROM #SubgroupData
    WHERE CostElementName LIKE 'Actual%' --actual costs are summed, not averaged
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CategoryGroupCode,
             CostElementId,
             CostElementName,
             CostElementCategory,
             Appn,
             WeaponSystemId,
             WeaponSystemName;



    IF @Debug = 1
    BEGIN
        SELECT 'group averages';
        SELECT *
        FROM #GroupData
        ORDER BY CostElementCategory,
                 CostElementName,
                 PayPlan,
                 GradeLevel,
                 CategoryGroupCode;

    END;


    DROP TABLE IF EXISTS #PayPlanData;
    CREATE TABLE #PayPlanData
    (
        PayPlan NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        GradeType NVARCHAR(3) NULL,
        costelementid INT NULL,
        costelementname NVARCHAR(250) NULL,
        costelementcategory NVARCHAR(50) NULL,
        weaponsystemid INT NULL,
        weaponsystemname NVARCHAR(50) NULL,
        appn NVARCHAR(25) NULL,
        Inventory INT NULL,
        amount NUMERIC(26, 2) NULL,
        AmcosVersionId INT NULL,
        amcosversionidstart INT NULL,
        amcosversionidend INT NULL
    );

    INSERT INTO #PayPlanData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        costelementid,
        costelementname,
        costelementcategory,
        weaponsystemid,
        weaponsystemname,
        appn,
        Inventory,
        amount,
        amcosversionidstart,
        amcosversionidend,
        AmcosVersionId
    )
    --to get group level data we just do a simple weighted average using inventory
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CostElementId,
           CostElementName,
           CostElementCategory,
           WeaponSystemId,
           WeaponSystemName,
           Appn,
           SUM(Inventory),
           SUM(Amount * Inventory) / SUM(Inventory),
           MAX(AmcosVersionIdStart),
           MAX(AmcosVersionIdEnd),
           MAX(AmcosVersionId)
    FROM #SubgroupData
    WHERE costelementname NOT LIKE 'Actual%' --everthing is averaged except actual costs
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CostElementId,
             CostElementName,
             CostElementCategory,
             Appn,
             WeaponSystemId,
             WeaponSystemName;


    INSERT INTO #PayPlanData
    (
        PayPlan,
        GradeLevel,
        GradeType,
        costelementid,
        costelementname,
        costelementcategory,
        weaponsystemid,
        weaponsystemname,
        appn,
        Inventory,
        amount,
        amcosversionidstart,
        amcosversionidend,
        AmcosVersionId
    )
    --to get group level data we just do a simple weighted average using inventory
    SELECT PayPlan,
           GradeLevel,
           GradeType,
           CostElementId,
           CostElementName,
           CostElementCategory,
           WeaponSystemId,
           WeaponSystemName,
           Appn,
           SUM(Inventory),
           SUM(Amount),
           MAX(AmcosVersionIdStart),
           MAX(AmcosVersionIdEnd),
           MAX(AmcosVersionId)
    FROM #SubgroupData
    WHERE costelementname LIKE 'Actual%' --actual costs are summed, not averaged
    GROUP BY PayPlan,
             GradeLevel,
             GradeType,
             CostElementId,
             CostElementName,
             CostElementCategory,
             Appn,
             WeaponSystemId,
             WeaponSystemName;




    IF @Debug = 1
    BEGIN
        SELECT 'pay plan averages';
        SELECT *
        FROM #PayPlanData
        ORDER BY PayPlan,
                 GradeLevel,
                 costelementcategory,
                 costelementname;

    END;

    IF @Debug = 0
    BEGIN
        /* clear out the existing cost table for all the CE IDs we are about to insert values for */
        -- AE
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'AE'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND MOS = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
              AND MHA = '-1' -- don't delete any location specific data since we aren't computing averages for those
              AND AmcosVersionId = @AmcosVersionId;
        -- AO
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'AO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND AOC = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
              AND MHA = '-1' -- don't delete any location specific data since we aren't computing averages for those
              AND AmcosVersionId = @AmcosVersionId;
        -- AWO
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'AWO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND WOMOS = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
              AND MHA = '-1' -- don't delete any location specific data since we aren't computing averages for those
              AND AmcosVersionId = @AmcosVersionId;
        -- NO
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'NO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND AOC = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
                             --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;
        -- RO
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'RO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND AOC = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
                             --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;
        -- NWO
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'NWO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND WOMOS = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
                               --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;
        -- RWO
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'RWO'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND WOMOS = '-1' --this will delete only Group and PP averages since both would have -1 for the subgroup code
                               --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;
        -- NE
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'NE'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND MOS = '-1' --this will delete only Group and PP averages since both would have -1 for the group code
                             --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;
        -- RE
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM #GroupData
                  WHERE PayPlan = 'RE'
                  GROUP BY CostElementId
              ) --only delete CEs that we are going to insert later
              AND MOS = '-1' --this will delete only Group and PP averages since both would have -1 for the group code
                             --AND mha = '-1' -- NG/R don't have location specific data so don't need this
              AND AmcosVersionId = @AmcosVersionId;




        DECLARE @CrunchTime SMALLDATETIME = CONVERT(SMALLDATETIME, GETDATE());


        /* Insert the averages we computed */
        --AE
        INSERT INTO crunch.Costs_AE
        (
            PayPlan,
            CMF,
            MOS,
            MHA,
            DependentStatus,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               '-1',
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #GroupData
        WHERE PayPlan = 'AE'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #PayPlanData
        WHERE PayPlan = 'AE'
              AND Amount > 0;

        --AO
        INSERT INTO crunch.Costs_AO
        (
            PayPlan,
            CMF,
            AOC,
            MHA,
            DependentStatus,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               '-1',
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #GroupData
        WHERE PayPlan = 'AO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #PayPlanData
        WHERE PayPlan = 'AO'
              AND Amount > 0;

        --AWO
        INSERT INTO crunch.Costs_AWO
        (
            PayPlan,
            Branch,
            WOMOS,
            MHA,
            DependentStatus,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               '-1',
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #GroupData
        WHERE PayPlan = 'AWO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId,
               -1
        FROM #PayPlanData
        WHERE PayPlan = 'AWO'
              AND Amount > 0;

        --NO
        INSERT INTO crunch.Costs_NO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'NO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'NO'
              AND Amount > 0;

        --RO
        INSERT INTO crunch.Costs_RO
        (
            PayPlan,
            CMF,
            AOC,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'RO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'RO'
              AND Amount > 0;

        --NE
        INSERT INTO crunch.Costs_NE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level

        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'NE'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'NE'
              AND Amount > 0;

        --RE
        INSERT INTO crunch.Costs_RE
        (
            PayPlan,
            CMF,
            MOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'RE'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'RE'
              AND Amount > 0;

        --NWO
        INSERT INTO crunch.Costs_NWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'NWO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'NWO'
              AND Amount > 0;


        --RWO
        INSERT INTO crunch.Costs_RWO
        (
            PayPlan,
            Branch,
            WOMOS,
            CostElementId,
            GradeType,
            GradeLevel,
            WeaponSystemId,
            Amount,
            CrunchTime,
            AmcosVersionId
        )
        -- -1 to indicate there is no subgroup since we are doing avg at the group level
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               CostElementId,
               GradeType,
               GradeLevel,
               WeaponSystemId,
               Amount,
               @CrunchTime,
               AmcosVersionId
        FROM #GroupData
        WHERE PayPlan = 'RWO'
              AND Amount > 0
        UNION
        -- double -1 to indicate there is no grp or subgrp since we are doing acg at the PP level
        SELECT PayPlan,
               '-1',
               '-1',
               costelementid,
               GradeType,
               GradeLevel,
               weaponsystemid,
               amount,
               @CrunchTime,
               AmcosVersionId
        FROM #PayPlanData
        WHERE PayPlan = 'RWO'
              AND Amount > 0;

    END;

END;