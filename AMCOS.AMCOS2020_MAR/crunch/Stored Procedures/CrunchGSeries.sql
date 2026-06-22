-- Stored Procedure

/*
-- Author:Dan Hogan
-- Create date: 9/23/2019
-- modified on 1/15/2020 to consolidate special pays into one single g series crunch following the use of warehouse location
-- modified on 4/1/2020 to add in calculation of base pay
-- modified on 7/3/2020 to add in non-foreign COLA calculation
-- modified on 1/11/2023 to add in observation of XXXX location for all gs occupations
-- Description:	Crunch GS
*/

/*
This is a complicated crunch when it comes to incorporating special pay, so the outline for it is as follows:
 1) generate pay schedules
      do this by creating a master list of all pay for all locations to include location and occupation specific pay
	  stored procedure fails if an occupation or location is not in the respective table
*/
CREATE   PROCEDURE [crunch].[CrunchGSeries]
    @AmcosVersionId INT = -1,
    @Debug AS BIT = 0 --to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
AS
BEGIN
    /* Integrate payschedule, all possible series types, and inventory */
    DROP TABLE IF EXISTS #Pay_Inv;
    CREATE TABLE #Pay_Inv
    (
        PayPlan NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        Step INT NOT NULL,
        Inventory INT NULL,
        LocationId INT NOT NULL,
        LocationCode NVARCHAR(150) NULL,
        LocationName NVARCHAR(300) NULL,
        NumberOfDependents INT NOT NULL
            DEFAULT (-1),
        AmcosVersionId INT NOT NULL,
        Pay NUMERIC(15, 2) NULL,
        DataSource NVARCHAR(25) NULL,
        Valid BIT NULL
    );
    INSERT INTO #Pay_Inv
    (
        PayPlan,
        GradeLevel,
        CategoryGroupCode,
        CategorySubgroupCode,
        Step,
        LocationId,
        AmcosVersionId,
        Pay,
        DataSource,
        NumberOfDependents,
        Inventory
    )
    /* Bring in regular pay by generating all the series combinations, union in the special pay scenarios, and ultimately select the highest of the two */
    SELECT PayPlan,
           GradeLevel,
           MyGroup,
           CAST(Series AS NVARCHAR(5)),
           Step,
           LocationId,
           AmcosVersionId,
           MAX(Rate),
           'inventory',
           -1 AS NumberOfDependents,
           MAX(Inventory) AS inventory
    FROM
    (
        SELECT a.PayPlan,
               a.GradeLevel,
               LEFT(b.CategorySubgroupCode, 2) + '00' AS MyGroup,
               CAST(b.CategorySubgroupCode AS NVARCHAR(5)) AS Series,
               a.Step,
               a.LocationId,
               a.AmcosVersionId,
               a.Rate,
               'inventory' AS DataSource,
               b.Inventory
        FROM PaySchedule.PaySchedule_G_Series AS a
            INNER JOIN
            (
                SELECT PayPlan,
                       CategoryGroupCode,
                       CategorySubgroupCode,
                       LocationId,
                       GradeLevel,
                       Step,
                       AmcosVersionId,
                       SUM(Inventory) AS Inventory
                FROM data.KnownInventory
                WHERE AmcosVersionId = @AmcosVersionId
                      AND PayPlan IN ( 'GS', 'GG', 'GL' )
                GROUP BY PayPlan,
                         CategoryGroupCode,
                         CategorySubgroupCode,
                         LocationId,
                         GradeLevel,
                         Step,
                         AmcosVersionId
            ) AS b
                ON a.GradeLevel = b.GradeLevel
                   AND b.PayPlan = a.PayPlan
                   AND b.LocationId = a.LocationId
                   AND a.Step = b.Step
				   AND (
					a.CategorySubgroupCode = b.CategorySubgroupCode
						 OR a.CategorySubgroupCode = '-1'
					)
        WHERE a.AmcosVersionId = @AmcosVersionId
              AND b.AmcosVersionId = @AmcosVersionId
              AND a.LocationId <> -1 

		--2025-03-30 BJM - Removed below as we need to include special pay as inventory
			  ---------------------------------------------------------------------------------
			  --don't allow in base pay since we don't use that
              --AND a.CategorySubgroupCode = '-1' ---1 means it applies to all subgroups (not special pay) which is what we want
        --UNION
        ----now bring in payschedules for specific subgroups which is special pay
        --SELECT PayPlan,
        --       GradeLevel,
        --       CategoryGroupCode,
        --       CAST(CategorySubgroupCode AS NVARCHAR(5)),
        --       Step,
        --       LocationId,
        --       AmcosVersionId,
        --       Rate,
        --       'special' AS DataSource,
        --       0 AS inventory
        --FROM PaySchedule.PaySchedule_G_Series
        --WHERE AmcosVersionId = @AmcosVersionId
        --      AND CategorySubgroupCode <> '-1'
        --      --7/17/2023 added to prevent cyber pay from coming in as we aren't ready for that in our costs
        --      AND WorkRoleCode = '-1'
    ) AS a
    GROUP BY PayPlan,
             GradeLevel,
             MyGroup,
             Series,
             Step,
             LocationId,			 
             AmcosVersionId;

    IF @Debug = 1
    BEGIN
        --subgroup data void of inventory for delete
        SELECT 'pay inv table 1';
        SELECT *
        FROM #Pay_Inv
        WHERE locationid IN (12506,12509,12510);

    END;


    --now bring in firefighters and assign them a step 5
    --because firefighter pay is very unique we need to generate these scenarios for all locations
    --we won't use inventory because AMCOS uses custom 5 digit subgroups for which there is no inventory
    INSERT INTO #Pay_Inv
    (
        PayPlan,
        GradeLevel,
        CategoryGroupCode,
        CategorySubgroupCode,
        Step,
        LocationId,
        AmcosVersionId,
        Pay,
        DataSource,
        NumberOfDependents,
        Inventory
    )
    SELECT a.PayPlan,
           a.GradeLevel,
           LEFT(b.OccupationalSeriesNumber, 2) + '00',
           b.OccupationalSeriesNumber,
           a.Step,
           a.LocationId,
           a.AmcosVersionId,
           a.Rate,
           'fill-in',
           -1 AS NumberOfDependents,
           0 AS inventory
    FROM PaySchedule.PaySchedule_G_Series AS a
        CROSS JOIN
        (
            SELECT OccupationalSeriesNumber
            FROM lookup.GS_OccupationalSeries
            WHERE OccupationalSeriesNumber LIKE '0081%'
                  AND LEN(OccupationalSeriesNumber) = 5
                  AND @AmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        ) AS b
    WHERE a.PayPlan = 'GS'
          AND a.AmcosVersionId = @AmcosVersionId
          AND a.CategorySubgroupCode = '-1' -- not subgroup specific (special pay) scenarios
          AND a.LocationId <> '-1' --no GS base pay, only pay for specific locations is what we want
          AND a.Step = 5;


    --bring in overseas where we know we have inventory
    INSERT INTO #Pay_Inv
    (
        PayPlan,
        GradeLevel,
        CategoryGroupCode,
        CategorySubgroupCode,
        Step,
        LocationId,
        AmcosVersionId,
        Pay,
        DataSource,
        NumberOfDependents,
        Inventory
    )
    SELECT a.PayPlan,
           a.GradeLevel,
           b.CategoryGroupCode AS mygroup,
           b.CategorySubgroupCode AS series,
           b.Step,
           b.LocationId,
           b.AmcosVersionId,
           a.Rate,
           'inventory' AS DataSource,
           d.NumberOfDependents,
           b.Inventory
    FROM PaySchedule.PaySchedule_G_Series AS a
        INNER JOIN
        (
            SELECT PayPlan,
                   CategoryGroupCode,
                   CategorySubgroupCode,
                   LocationId,
                   GradeLevel,
                   Step,
                   AmcosVersionId,
                   SUM(Inventory) AS Inventory
            FROM data.KnownInventory
            WHERE AmcosVersionId = @AmcosVersionId
                  AND PayPlan IN ( 'GS', 'GG' ) --overseas pay is only for these two pay plan types
            GROUP BY PayPlan,
                     CategoryGroupCode,
                     CategorySubgroupCode,
                     LocationId,
                     GradeLevel,
                     Step,
                     AmcosVersionId
        ) AS b
            ON b.AmcosVersionId = a.AmcosVersionId
               AND b.GradeLevel = a.GradeLevel
               AND b.Step = a.Step
               AND b.PayPlan = a.PayPlan
        INNER JOIN
        (
            SELECT a.LocationCode,
                   c.LocationId
            FROM lookup.DosLocations AS a
                LEFT OUTER JOIN
                (
                    SELECT LocationCode,
                           CASE
                               WHEN Amt > 0 THEN
                                   1
                               ELSE
                                   0
                           END AS costs
                    FROM dataload.DoSLivingAllowance
                    WHERE AmcosVersionId = @AmcosVersionId
                    UNION
                    SELECT LocationCode,
                           CASE
                               WHEN DangerPay > 0
                                    OR PostAllowance > 0
                                    OR Hardship > 0 THEN
                                   1
                               ELSE
                                   0
                           END AS costs
                    FROM dataload.DoSPostAllowance
                    WHERE AmcosVersionId = @AmcosVersionId
                ) AS b
                    ON a.LocationCode = b.LocationCode
                LEFT OUTER JOIN warehouse.Location AS c
                    ON a.LocationCode = c.SourceSystemCode
            WHERE c.LocationType = 'Civilian Overseas'
                  AND b.costs = 1
        ) AS c
            ON c.LocationId = b.LocationId
        CROSS JOIN
        (
            --SELECT 0 AS NumberOfDependents 
            SELECT DISTINCT
                   NumberOfDependents
            FROM dataload.MilitarySpendableIncome
            WHERE AmcosVersionId = @AmcosVersionId
        ) AS d
    WHERE a.AmcosVersionId = @AmcosVersionId
          AND a.LocationId = -1 --overseas uses base pay
          AND a.CategorySubgroupCode = '-1'; --we only need manufacturer subgroups for payschedules that are generic

    --added 5/11/2022 to remove null inventory, purpose here is to avoid having this serve as fill in the blank later when we catch null invenotry values during the computation and change them to 1
    --prior to this clause all null inventory values were being changed to 1 in inventory and added to the weighted average which was incorrect

    IF @Debug = 1
    BEGIN
        --subgroup data void of inventory for delete
        SELECT 'pay inv table 2';
        SELECT *
        FROM #Pay_Inv
        WHERE locationid IN (12506,12509,12510);

    END;

    DELETE FROM #Pay_Inv
    WHERE (
              Inventory = 0
              OR Inventory IS NULL
          )
          AND DataSource = 'inventory';

    INSERT INTO #Pay_Inv
    (
        PayPlan,
        GradeLevel,
        CategoryGroupCode,
        CategorySubgroupCode,
        Step,
        LocationId,
        AmcosVersionId,
        Pay,
        Valid,
        NumberOfDependents,
        DataSource,
        Inventory
    )
    --bring in overseas areas where we are missing inventory


    SELECT c.PayPlan,
           d.GradeLevel,
           '-1' AS mygroup,
           '-1' AS series,
           5,
           a.LocationId,
           @AmcosVersionId,
           E.Rate,
           1,
           b.NumberOfDependents,
           'fill-in',
           NULL AS inventory
    FROM
    (
        SELECT a.LocationCode,
               c.LocationId
        FROM lookup.DosLocations AS a
            LEFT OUTER JOIN
            (
                SELECT LocationCode,
                       CASE
                           WHEN Amt > 0 THEN
                               1
                           ELSE
                               0
                       END AS costs
                FROM dataload.DoSLivingAllowance
                WHERE AmcosVersionId = @AmcosVersionId
                UNION
                SELECT LocationCode,
                       CASE
                           WHEN DangerPay > 0
                                OR PostAllowance > 0
                                OR Hardship > 0 THEN
                               1
                           ELSE
                               0
                       END AS costs
                FROM dataload.DoSPostAllowance
                WHERE AmcosVersionId = @AmcosVersionId
            ) AS b
                ON a.LocationCode = b.LocationCode
            LEFT OUTER JOIN warehouse.Location AS c
                ON a.LocationCode = c.SourceSystemCode
        WHERE c.LocationType = 'Civilian Overseas'
              AND b.costs = 1
    ) AS a
        CROSS JOIN
        (
            --get number of possible NumberOfDependents
            SELECT DISTINCT
                   NumberOfDependents
            FROM dataload.MilitarySpendableIncome
            WHERE AmcosVersionId = @AmcosVersionId
        ) AS b
        --get available pay plans for overseas costs
        CROSS JOIN
        (SELECT 'GS' AS PayPlan UNION SELECT 'GG') AS c
        --get valid grade levels
        CROSS JOIN
        (
            SELECT DISTINCT
                   GradeLevel
            FROM lookup.Valid_OPM_Series_GradeLevels
            WHERE @AmcosVersionId
            BETWEEN amcosversionidstart AND amcosversionidend
        ) AS d
        --bring in the payschedule data 
        INNER JOIN
        (
            SELECT *
            FROM PaySchedule.PaySchedule_G_Series
            WHERE Step = 5
                  AND CategorySubgroupCode = '-1'
                  AND LocationId = -1
                  AND AmcosVersionId = @AmcosVersionId
        ) AS E
            ON E.PayPlan = c.PayPlan
               AND E.GradeLevel = d.GradeLevel
    WHERE CONCAT(E.PayPlan, E.GradeLevel, E.LocationId) NOT IN
          (
              SELECT DISTINCT
                     CONCAT(PayPlan, GradeLevel, LocationId)
              FROM #Pay_Inv AS z
              WHERE DataSource = 'inventory'
          )
    UNION

    --bring in conus areas where we are missing inventory


    SELECT a.PayPlan,
           a.GradeLevel,
           '-1' AS mygroup,
           '-1' AS series,
           a.Step,
           a.LocationId,
           @AmcosVersionId,
           a.Rate,
           1,
           -1 AS NumberOfDependents,
           'fill-in',
           NULL AS inventory
    FROM
    (
        SELECT *
        FROM PaySchedule.PaySchedule_G_Series
        WHERE Step = 5
              AND CategorySubgroupCode = '-1'
              AND LocationId <> -1
              AND AmcosVersionId = @AmcosVersionId
              AND CONCAT(PayPlan, GradeLevel, LocationId) NOT IN
                  (
                      SELECT DISTINCT
                             CONCAT(PayPlan, GradeLevel, LocationId)
                      FROM #Pay_Inv AS z
                      WHERE DataSource = 'inventory'
                  )
    ) AS a;





    -- --now bring in inventory
    -- UPDATE #Pay_Inv
    -- SET inventory = b.inventory,
    --     [DataSource] = 'Inventory'
    -- FROM #Pay_Inv AS a
    --     INNER JOIN
    --     (
    --         --aggregate to get rid of any YOS data which we don't use for this
    --         SELECT SUM(Inventory) AS inventory,
    --                PayPlan,
    --                CategorySubgroupCode,
    --                LocationId,
    --                Step,
    --                GradeLevel
    --         FROM data.knownInventory
    ----only bring in location for CONUS G series, there is another crunch for OCONUS G series
    --WHERE AmcosVersionId=@AmcosVersionId
    --         GROUP BY PayPlan,
    --                  CategorySubgroupCode,
    --                  LocationId,
    --                  Step,
    --                  GradeLevel

    --     ) AS b
    --         ON a.PayPlan = b.PayPlan
    --            AND a.CategorySubgroupCode = b.CategorySubgroupCode
    --            AND a.step = b.step
    --            AND a.GradeLevel = b.GradeLevel
    --            AND a.locationid = b.locationid

    --commented out the below on 9/8/2020 when we stopped filling in all the gaps in inventory
    --any subgroupdcode which is completely void of inventory means the PayPlan isn't using it and thus we shouldn't either
    --   UPDATE a
    --   SET a.DataSource = 'DELETE'
    --   FROM #Pay_Inv AS a
    --       INNER JOIN
    --       (
    --           SELECT PayPlan,
    --                  CategorySubgroupCode,
    --                  SUM(ISNULL(inventory, 0)) AS inv
    --           FROM #Pay_Inv
    --		WHERE LEN(CategorySubgroupCode)=4
    --           GROUP BY PayPlan,
    --                    CategorySubgroupCode

    --           HAVING SUM(ISNULL(inventory, 0)) = 0
    --       ) AS b
    --           ON a.PayPlan = b.PayPlan
    --			--we don't have inventory at the 5 digit subgroup since that is an AMCOS unique thing so we pair it down to the 4 group level
    --              AND LEFT(a.CategorySubgroupCode,4) = LEFT(b.CategorySubgroupCode,4)


    ----any row which lacks inventory AND is not valid needs to go
    --UPDATE #Pay_Inv  SET DataSource='DELETE'
    -- WHERE inventory=0 AND valid=0


    UPDATE #Pay_Inv
    SET Inventory = NULL
    WHERE Inventory = 0;

    IF @Debug = 1
    BEGIN
        --subgroup data void of inventory for delete
        SELECT 'pay inv table';
        SELECT *
        FROM #Pay_Inv
        WHERE locationid IN (12506,12509,12510);

    END;



    --get single values for later use in special pay and non special pay calculations
    -- these single values are for every pay plan that uses them
    DECLARE @PostRetHealthIns NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'PostRetHealthIns', @AmcosVersionId);
    DECLARE @PostRetLifeIns NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'PostRetLifeIns', @AmcosVersionId);
    DECLARE @Training NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'Training', @AmcosVersionId);
    DECLARE @groceries NUMERIC(17, 2) = crunch.GetSingleValue('AA', 'DiscountGroceries', @AmcosVersionId);

    -- create a master table to hold costs
    CREATE TABLE #PayByLocationCosts
    (
        PayPlan NVARCHAR(3) NOT NULL,
        GradeLevel TINYINT NULL,
        CategoryGroupCode NVARCHAR(4) NOT NULL,
        CategorySubgroupCode NVARCHAR(5) NOT NULL,
        SubgroupTitle NVARCHAR(150) NULL,
        BasePay NUMERIC(15, 2) NOT NULL,
        CostAmount NUMERIC(15, 2) NOT NULL,
        LocationName NVARCHAR(250) NULL,
        LocationCode NVARCHAR(100) NULL,
        LocationType NVARCHAR(500) NULL,
        CostElementId INT NOT NULL,
        CostElementName NVARCHAR(150) NOT NULL,
        CostElementCategory NVARCHAR(150) NOT NULL,
        Appn NVARCHAR(25) NOT NULL,
        AmcosVersionId INT NOT NULL,
        LocationId INT NOT NULL,
        NumberOfDependents INT NOT NULL,
        DataSource NVARCHAR(50) NOT NULL,
        Inventory INT NOT NULL
    );
    INSERT INTO #PayByLocationCosts
    (
        PayPlan,
        GradeLevel,
        CategoryGroupCode,
        CategorySubgroupCode,
        BasePay,
        CostAmount,
        CostElementId,
        CostElementName,
        CostElementCategory,
        Appn,
        AmcosVersionId,
        LocationId,
        NumberOfDependents,
        DataSource,
        Inventory
    )

    --insert is a cross join between all locations and their base pay and all possible cost elements
    SELECT DISTINCT
           a.PayPlan,
           a.GradeLevel,
           a.CategoryGroupCode,
           a.CategorySubgroupCode,
           a.avgpay,
           0,
           b.CostElementId,
           b.CostElementName,
           b.CostElementCategory,
           b.APPN,
           a.AmcosVersionId,
           a.LocationId,
           a.NumberOfDependents,
           a.DataSource,
           a.Inventory
    FROM
    (
        SELECT PayPlan,
               GradeLevel,
               CategoryGroupCode,
               CategorySubgroupCode,
               LocationId,
               AmcosVersionId,
               SUM(Pay * ISNULL(Inventory, 1)) / SUM(ISNULL(Inventory, 1)) AS avgpay,
               NumberOfDependents,
               DataSource,
               SUM(ISNULL(Inventory, 0)) AS Inventory
        FROM #Pay_Inv
        GROUP BY PayPlan,
                 GradeLevel,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 LocationId,
                 AmcosVersionId,
                 NumberOfDependents,
                 DataSource
    ) AS a
        INNER JOIN lookup.CostElement AS b
            ON a.PayPlan = b.PayPlan
    WHERE @AmcosVersionId
    BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd;

    UPDATE #PayByLocationCosts
    SET LocationName = b.DisplayName,
        LocationCode = b.SourceSystemCode,
        LocationType = b.LocationType
    FROM #PayByLocationCosts AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId;

    IF @Debug = 1
    BEGIN
        SELECT 'full  pay cost table for insert before comp';
        SELECT *
        FROM #PayByLocationCosts
        WHERE Inventory > 0
              AND CategorySubgroupCode = '2210'
              AND LocationId = 964
        ORDER BY LocationName,
                 CategorySubgroupCode;

        SELECT 'base pay is null';
        SELECT *
        FROM #PayByLocationCosts
        WHERE BasePay IS NULL;
    END;

    DECLARE @FireFighterHours NUMERIC(8, 2) = crunch.GetSingleValue('GS', 'FirefighterHours', @AmcosVersionId);
    DECLARE @FireFighterNonOTHours NUMERIC(8, 2)
        = crunch.GetSingleValue('GS', 'FirefighterNonOTHours', @AmcosVersionId);
    DECLARE @FirefighterBasicPay2Hours NUMERIC(8, 2)
        = crunch.GetSingleValue('GS', 'FirefighterBasicPay2Hours', @AmcosVersionId);

    --Army CivPay; Compensation - Basic; Avg Cost of Base Pay (Civilian) 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay
    WHERE CostElementId IN ( 275, 3492, 3505 )
          AND LEFT(CategorySubgroupCode, 4) <> '0081'; --firefighters are calculated differently

    --144 hours non-exempt firefighter
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay / @FireFighterHours * @FireFighterNonOTHours * 26 --26 pay periods
    WHERE CostElementId IN ( 275 ) --only gs
          AND CategorySubgroupCode = '0081a';

    --all other firefighters
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay
    WHERE CostElementId IN ( 275 ) --only gs
          AND CategorySubgroupCode IN ( '0081b', '0081c', '0081d', '0081e' );


    --Basic Pay 2 - firefighters only
    UPDATE #PayByLocationCosts
    --get the firefighter hourly rate and multiple by the basic 2 hours
    SET CostAmount = BasePay / @FireFighterHours * @FirefighterBasicPay2Hours * 26 --26 pay periods
    WHERE CostElementId IN ( 4894 ) --only gs
          AND CategorySubgroupCode IN ( '0081b', '0081d' ); --only 40+ work week firefighters who put in at least 106 hours


IF @debug = 1
BEGIN
    SELECT 'Distinct location name for GS from paylocation cost temp table';

    SELECT distinct a.locationid, displayname
    FROM #PayByLocationCosts AS a
    left JOIN warehouse.Location AS b
        ON a.LocationId = b.LocationId
    WHERE a.AmcosVersionId = 202501
      AND a.PayPlan IN ( 'GS')

      AND b.LocationType IN ('Nonforeign Area', 'Locality Pay Area')
      AND a.CostElementId IN (4856, 4857, 4858)
	  order by a.locationid;



    SELECT 'Paybylocation temp table for GS';

    SELECT *
    FROM #PayByLocationCosts AS a
    --INNER JOIN warehouse.Location AS b
        --ON a.LocationId = b.LocationId
    WHERE a.AmcosVersionId = 202501
      AND a.PayPlan IN ( 'GS')
	  and a.locationid in(963, 987, 12500, 12502, 12504, 12505, 12507, 1007, 12506,12509,12510)
      --AND (
           -- b.DisplayName LIKE '%Rest%' 
         -- OR b.DisplayName LIKE '%Hawaii%' 
        --  OR b.DisplayName LIKE '%Guam%' 
        -- OR b.DisplayName LIKE '%Alaska%'
      --)
      --AND b.LocationType IN ('Nonforeign Area', 'Locality Pay Area')
      --AND a.CostElementId IN (4856, 4857, 4858);
END;




    --Non-foreign COLA
    --NFC is the base pay * a cola % per OPM, see traffic in comments below
    --because the gs_locality pay table has the acronym but the #paybylocationcosts uses locationid
    --we do an intermediate join to bring the two together
	UPDATE #PayByLocationCosts
    SET CostAmount = ISNULL(c.ColaRate / 100, 0) * a.BasePay
    FROM #PayByLocationCosts AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
			INNER JOIN [lookup].[NonforeignArea] x
			ON x.LocalityCode = b.SourceSystemCode
        INNER JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
            ON x.NonforeignAreaCode = c.NonforeignAreaCode
    WHERE @AmcosVersionId = c.AmcosVersionId AND 
          b.LocationType IN ('Nonforeign Area', 'Locality Pay Area') --just in case any other location codes match our locality areas
		   AND a.CostElementId IN ( 4856, 4857, 4858 );







if @debug = 1
begin
select 'Non Foreign Cola Calculation'
select *, c.AmcosVersionId as versionids
--, ISNULL(c.ColaRate / 100, 0) * a.BasePay as Non_foreign_cola_pay
FROM #PayByLocationCosts AS a
INNER JOIN warehouse.Location AS b
            ON a.LocationId = b.LocationId
			INNER JOIN [lookup].[NonforeignArea] x
			ON x.LocalityCode = b.SourceSystemCode
        INNER JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
            ON x.NonforeignAreaCode = c.NonforeignAreaCode
    WHERE @AmcosVersionId = c.AmcosVersionId 
	AND   b.LocationType IN ('Nonforeign Area', 'Locality Pay Area') --just in case any other location codes match our locality areas
		    and a.CostElementId IN ( 4856, 4857, 4858 )
END;




	-- Remove 4896 values that are not non foreign area.
	--DELETE FROM #Costs WHERE CostElementId = 4896 AND LocationId NOT IN (SELECT LocationId FROM warehouse.Location a JOIN lookup.NonforeignArea b ON b.LocalityCode = a.SourceSystemCode WHERE @AmcosVersionId = b.AmcosVersionId)


	--UPDATE #PayByLocationCosts
 --   SET CostAmount = ISNULL(c.ColaRate / 100, 0) * a.BasePay
 --   FROM #PayByLocationCosts AS a
 --       INNER JOIN warehouse.Location AS b
 --           ON a.LocationId = b.LocationId
 --       INNER JOIN PaySchedule.NonforeignAreaCostOfLivingAllowances AS c
 --           ON b.SourceSystemCode = c.NonforeignAreaCode
 --   WHERE @AmcosVersionId = c.AmcosVersionId
 --         AND b.LocationType = 'Nonforeign Area' --just in case any other location codes match our locality areas
 --         AND a.CostElementId IN ( 4856, 4857, 4858 );

    /*
	From: Byrne, Robbins [ROBBINS.BYRNE@opm.gov]
	Sent: Thursday, July 02, 2020 11:38 AM
	To: Hogan, Daniel J CTR (USA)
	Subject: RE: [Non-DoD Source] RE: Nonforeign COLA
	Dan,

	Yes, that is the correct calculation.  Please let me know if you have further questions.
	Thanks, Robbins

 Robbins Byrne
 HR Specialist (Compensation)
 Employee Services/Pay and Leave/Pay Systems
 U.S. Office of Personnel Management
 1900 E Street NW, Room 7H31-17
 Washington, DC 20415-8200
 Office:(202) 606-1317
 Cell:(202) 997-9883 (telework phone)
 Email:robbins.byrne@opm.gov

	From: Hogan, Daniel J CTR (USA) [Caution-mailto:daniel.j.hogan26.ctr@mail.mil]
	Sent: Thursday, July 2, 2020 11:26 AM
	To: Byrne, Robbins <ROBBINS.BYRNE@opm.gov>
	Cc: Popp, M D CIV USARMY HQDA ASA FM (USA) <marsha.d.popp.civ@mail.mil>
	Subject: RE: [Non-DoD Source] RE: Nonforeign COLA



	Robbins,

	Thank you calling me back.  Per our discussion the calculation is as follows:

	(base pay * (1+locality %) ) * (1 + nfc %)
	or stated another way
	((base pay) + (base pay * locality %)) * (1 + nfc %)
	The end result is that NFC is calculated the same for both a non-special rate AND a special rate in that NFC is applied to the individual's total salary for their location and occupation.


	*/


    --###################       Overseas costs                    #######################-----------------



    --LQA Costs
    --According to the DTMO site https://www.defensetravel.dod.mil/site/faqlqa.cfm
    --GS14& 15 are group 2
    --gs10-13 are group 3
    --gs1-9 ARE group 4

    --group 4
    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 1 AND 9
          AND b.[Group] = 4
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';


    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 1 AND 9
          AND b.[Group] = 4
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';

    --group 3
    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 10 AND 13
          AND b.[Group] = 3
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';

    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 10 AND 13
          AND b.[Group] = 3
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';

    --group 2
    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 14 AND 15
          AND b.[Group] = 2
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 0
          AND a.NumberOfDependents = 0
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';

    UPDATE #PayByLocationCosts
    SET CostAmount = b.Amt
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSLivingAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE a.GradeLevel
          BETWEEN 14 AND 15
          AND b.[Group] = 2
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.Family = 1
          AND a.NumberOfDependents >= 1
          AND a.CostElementId IN ( 4859, 4860, 4861 )
          AND a.LocationType = 'Civilian Overseas';


    --Post Allowance costs
    --percentage based on spendable income
    --per DSSR 054.1 the post allowance is NOT taxable
    UPDATE #PayByLocationCosts
    SET CostAmount = b.SpendableIncome * c.PostAllowance
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.MilitarySpendableIncome AS b
            ON a.BasePay
               BETWEEN b.LowerLimit AND b.UpperLimit
               AND b.NumberOfDependents = a.NumberOfDependents
        INNER JOIN dataload.DoSPostAllowance AS c
            ON a.LocationCode = c.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND c.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4862, 4863, 4864 )
          AND a.LocationType = 'Civilian Overseas';

    --Post Hardship Differential
    --percentage based on basic compensation
    --per DSSR 045.2 this IS INCLUDED for federal tax purposes
    UPDATE #PayByLocationCosts
    SET CostAmount = a.BasePay * b.Hardship
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4865, 4866, 4867 );





    --Danger Pay Allowance
    --percentage based on basic compensation
    --per DSSR 054.2 this IS INCLUDED for federal tax purposes
    UPDATE #PayByLocationCosts
    SET CostAmount = a.BasePay * b.DangerPay
    FROM #PayByLocationCosts AS a
        INNER JOIN dataload.DoSPostAllowance AS b
            ON a.LocationCode = b.LocationCode
    WHERE b.AmcosVersionId = @AmcosVersionId
          AND a.CostElementId IN ( 4868, 4869, 4870 )
          AND a.LocationType = 'Civilian Overseas';


    -- Discount Groceries 
    UPDATE #PayByLocationCosts
    SET CostAmount = @groceries
    WHERE CostElementId IN ( 4871, 4872, 4873 )
          AND LocationType = 'Civilian Overseas';

    --###################       End overseas costs                    #######################-----------------

    -- Army CivPay; Compensation - Other; Avg Cost of Other Compensation 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'OtherComp', @AmcosVersionId)
    WHERE CostElementId IN ( 284, 3493, 3506 )
          AND LEFT(CategorySubgroupCode, 4) <> '0081'; --firefighers use other comp without premium pay

    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'OtherCompNoPremium', @AmcosVersionId)
    WHERE CostElementId IN ( 284, 3493, 3506 )
          AND LEFT(CategorySubgroupCode, 4) = '0081'; --firefighers use other comp without premium pay


    -- Army CivPay; Benefits; Avg Cost of Benefits 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'BenefitsRet', @AmcosVersionId)
    WHERE CostElementId IN ( 286, 3487, 3500 );


    -- Army CivPay; Benefits; Avg Cost of Former Employee Compensation 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'FormerEmp', @AmcosVersionId)
    WHERE CostElementId IN ( 282, 3503, 3490 );

    -- Army CivPay; Cash Awards; Avg Cost of Cash Awards 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'CashAwards', @AmcosVersionId)
    WHERE CostElementId IN ( 279, 3491, 3504 );

    -- Army CivPay; Holiday Pay; Avg Cost of Holiday Pay 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'Holiday', @AmcosVersionId)
    WHERE CostElementId IN ( 276, 3494, 3507 )
          AND LEFT(CategorySubgroupCode, 4) <> '0081'; --firefighers don't get holiday pay

    -- Army CivPay; Overtime Pay; Avg Cost of Overtime Pay 
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay * crunch.GetSingleValue(PayPlan, 'Ovrt', @AmcosVersionId)
    WHERE CostElementId IN ( 277, 3508, 3495 )
          AND LEFT(CategorySubgroupCode, 4) <> '0081'; --firefighers use a special method

    DECLARE @Firefighter144hrRegOTHrs NUMERIC(8, 2)
        = crunch.GetSingleValue('GS', 'Firefighter144hrRegOTHrs', @AmcosVersionId);

    --Firefighter Regular OT is calculated for only one case, the 144 hr firefighter
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay / @FireFighterHours * 1.5 * @Firefighter144hrRegOTHrs * 26 --1 hr and OT is time and a half
    WHERE CostElementId IN ( 4895 )
          AND CategorySubgroupCode IN ( '0081a' );



    --Firefighter OT is calculated at 1 hour so users can scale accordingly
    --Non-Exempt is easy
    UPDATE #PayByLocationCosts
    SET CostAmount = BasePay / @FireFighterHours * 1.5 * 1 --1 hr and OT is time and a half
    WHERE CostElementId IN ( 277 )
          AND CategorySubgroupCode IN ( '0081a', '0081b', '0081c' );


    --Exempt is slightly more complicated
    DECLARE @annualhours NUMERIC(8, 2) = crunch.GetSingleValue('GP', 'annualPaidHours', @AmcosVersionId);

    UPDATE #PayByLocationCosts
    SET CostAmount =
        --basically, if the Firefighter hourly rate is greater than  GS10 Step1 hourly rate 
        --then we go into a max situation
        --max of
        -- 1.5 * GS10S1
        -- firefighter rate
        --else they get their 1.5 times firefighter pay like non-exempt
        --
        CASE
            WHEN (a.BasePay / @FireFighterHours > b.Rate / @annualhours)
                 AND (1.5 * b.Rate / @annualhours > a.BasePay / @FireFighterHours) THEN
                1.5 * b.Rate / @annualhours
            WHEN (a.BasePay / @FireFighterHours > b.Rate / @annualhours)
                 AND (1.5 * b.Rate / @annualhours < a.BasePay / @FireFighterHours) THEN
                a.BasePay / @FireFighterHours
            ELSE
                a.BasePay / @FireFighterHours * 1.5
        END * 1 --we only use one hour so users can scale up as needed
    FROM #PayByLocationCosts AS a
        INNER JOIN
        (
            --exempt folks are compared against GS10S1 so we need that data
            SELECT *
            FROM data.PaySchedules
            WHERE PayPlan = 'GS'
                  AND AmcosVersionId = @AmcosVersionId
                  AND GradeLevel = 10
                  AND Step = 1
                  AND RateType = 'Annual'
        ) AS b
            ON a.PayPlan = b.PayPlan
               AND a.LocationId = b.LocationId
    WHERE a.CostElementId IN ( 277 )
          AND a.CategorySubgroupCode IN ( '0081d', '0081e' );



    -- OMA; Training Costs; Training
    UPDATE #PayByLocationCosts
    SET CostAmount = @Training
    WHERE CostElementId IN ( 735, 3512, 3499 );


    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Health Insurance 
    UPDATE #PayByLocationCosts
    SET CostAmount = @PostRetHealthIns
    WHERE CostElementId IN ( 952, 3510, 3497 );


    -- Federal OM; Retired Pay Accrual; Avg Cost of Post Retirement Life Insurance 
    UPDATE #PayByLocationCosts
    SET CostAmount = @PostRetLifeIns
    WHERE CostElementId IN ( 951, 3498, 3511 );

    DELETE FROM #PayByLocationCosts
    WHERE CostAmount < 0;

    --there should be no costs for 0081 firefighter
    --so we delete those entries just to be sure
    --we also make sure 0081 is converted to an 'inventory' tag so that it is 
    --inserted in all locaitons as a group or PayPlan avg will not work for it
    DELETE FROM #PayByLocationCosts
    WHERE CategorySubgroupCode = '0081';

    UPDATE #PayByLocationCosts
    SET DataSource = 'inventory'
    WHERE CategorySubgroupCode LIKE '0081%';

    IF @Debug = 1
    BEGIN
        SELECT 'there should be no negative values';
        SELECT *
        FROM #PayByLocationCosts
        WHERE CostAmount < 0
        ORDER BY LocationName,
                 CategorySubgroupCode;
        SELECT 'full  pay cost table for insert';
        SELECT *
        FROM #PayByLocationCosts
        WHERE Inventory > 0
              AND CategorySubgroupCode = '0854'
              AND LocationId = 1839
        ORDER BY LocationName,
                 CategorySubgroupCode;
        SELECT 'there should be no null values';
        SELECT *
        FROM #PayByLocationCosts
        WHERE CostAmount IS NULL;

        SELECT 'GL1s';
        SELECT *
        FROM #PayByLocationCosts
        WHERE PayPlan = 'GS'
              AND GradeLevel = 1;
    END;

    IF @Debug = 0
    BEGIN
        --According to a discussion with the COR (Marsha Popp) on 8/24/2020 there were two main options on how to handle overseas and CONUS costs in terms of averaging:
        --a) assume a typical # of overseas dependants and average that with CONUS (# of dep=-1)
        --b) keep CONUS and OCONUS seperate and force the user to pick # of dep with -1 being called Not Applicable
        --because A is a truer average that was chosen 
        --for overseas dependent numbers we assumed civilian and spouse was typical so 1 total dependant
        DECLARE @conusdep INT = -1;
        DECLARE @oconusdep INT = 1;
        DECLARE @avgdepnumber INT = -1;


        --remove the old costs for this version and pay plan before inserting the new costs
        DELETE FROM crunch.Costs_G
        WHERE AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_G
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        --subgroup with location inserts , no fill in the blanks but include special
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               CostAmount,
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #PayByLocationCosts
        WHERE DataSource <> 'fill-in'
        UNION
        --subgroup without location inserts , no fill in, no 0 inventory special pay included in the avg
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               -1,
               @avgdepnumber
        FROM #PayByLocationCosts
        WHERE (
                  DataSource <> 'fill-in'
                  AND Inventory > 0
                  AND NumberOfDependents IN ( @conusdep, @oconusdep )
              )
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeLevel
        UNION
        --group with location inserts , no fill in, no 0 inventory special pay included in the avg
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #PayByLocationCosts
        WHERE DataSource <> 'fill-in'
              AND Inventory > 0
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CostElementId,
                 GradeLevel,
                 NumberOfDependents,
                 LocationId
        --group without location inserts , no fill in the blanks

        UNION
        SELECT PayPlan,
               CategoryGroupCode,
               '-1',
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               -1,
               @avgdepnumber
        FROM #PayByLocationCosts
        WHERE DataSource <> 'fill-in'
              AND Inventory > 0
              AND NumberOfDependents IN ( @conusdep, @oconusdep )
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CostElementId,
                 GradeLevel

        --pp with location inserts , fill in the blanks allowed
        UNION
        SELECT PayPlan,
               '-1',
               '-1',
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(   CostAmount * CASE Inventory
                                       WHEN 0 THEN
                                           1
                                       ELSE
                                           Inventory
                                   END
                  ) / SUM(   CASE Inventory
                                 WHEN 0 THEN
                                     1
                                 ELSE
                                     Inventory
                             END
                         ),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               LocationId,
               NumberOfDependents
        FROM #PayByLocationCosts
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel,
                 NumberOfDependents,
                 LocationId


        --pp without location inserts , no fill in the blanks
        UNION
        SELECT PayPlan,
               '-1',
               '-1',
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               SUM(CostAmount * Inventory) / SUM(Inventory),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               -1,
               @avgdepnumber
        FROM #PayByLocationCosts
        WHERE DataSource <> 'fill-in'
              AND Inventory > 0
              AND NumberOfDependents IN ( @conusdep, @oconusdep )
        GROUP BY PayPlan,
                 CostElementId,
                 GradeLevel

        --career program without location, do not allow fill in the blanks
        UNION
        SELECT a.PayPlan,
               '-1',
               '-1',
               b.CareerProgramNumber,
               a.CostElementId,
               a.PayPlan,
               a.GradeLevel,
               SUM(a.CostAmount * a.Inventory) / SUM(a.Inventory),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               -1,
               @avgdepnumber
        FROM #PayByLocationCosts AS a
            INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
        WHERE a.DataSource <> 'fill-in'
              AND a.Inventory > 0
              AND a.NumberOfDependents IN ( @conusdep, @oconusdep )
        GROUP BY a.PayPlan,
                 a.CostElementId,
                 a.GradeLevel,
                 b.CareerProgramNumber

        --career program with location, allow fill in the blanks
        UNION
        SELECT a.PayPlan,
               '-1',
               '-1',
               b.CareerProgramNumber,
               a.CostElementId,
               a.PayPlan,
               a.GradeLevel,
               SUM(   a.CostAmount * CASE a.Inventory
                                         WHEN 0 THEN
                                             1
                                         ELSE
                                             a.Inventory
                                     END
                  ) / SUM(   CASE a.Inventory
                                 WHEN 0 THEN
                                     1
                                 ELSE
                                     a.Inventory
                             END
                         ),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               a.LocationId,
               a.NumberOfDependents
        FROM #PayByLocationCosts AS a
            INNER JOIN xwalk.OccupationalSeriesToCareerProgram AS b
                ON a.CategorySubgroupCode = b.OccupationalSeriesNumber
        --WHERE inventory>0 
        GROUP BY a.PayPlan,
                 a.CostElementId,
                 a.GradeLevel,
                 a.NumberOfDependents,
                 b.CareerProgramNumber,
                 a.LocationId;



        --one final insert to catch any location non-specific subgroups we didn't already generate costs for
        --due to there being a lack of inventory (special pay and 5 digit subgroups have a tendance to fall into this category
        INSERT INTO crunch.Costs_G
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            CareerProgramNumber,
            CostElementId,
            GradeType,
            GradeLevel,
            Amount,
            CrunchTime,
            AmcosVersionId,
            LocationId,
            NumberOfDependents
        )
        --subgroup with location inserts , no fill in the blanks but include special
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               -1,
               CostElementId,
               PayPlan,
               GradeLevel,
               AVG(CostAmount),
               CONVERT(SMALLDATETIME, GETDATE()) AS CrunchTime,
               @AmcosVersionId,
               -1,
               @conusdep AS NumberOfDependents
        FROM #PayByLocationCosts
        WHERE CONCAT(CONCAT(PayPlan, CategorySubgroupCode), GradeLevel) NOT IN
              (
                  SELECT DISTINCT
                         CONCAT(CONCAT(PayPlan, OccupationalSeriesNumber), GradeLevel)
                  FROM crunch.Costs_G
                  WHERE LocationId = -1
                        AND @AmcosVersionId = AmcosVersionId
              )
              AND NumberOfDependents = @conusdep
              AND LocationId <> -1
              AND Inventory = 0
              AND CategorySubgroupCode <> '-1'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeLevel;


        --remove costs which are zero 
        DELETE FROM crunch.Costs_G
        WHERE Amount <= 0
              AND AmcosVersionId = @AmcosVersionId;
    END;
END;
GO
