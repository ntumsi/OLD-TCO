-- Stored Procedure

CREATE PROC [warehouse].[PopulatePPXwalk]
    @CategorySubgroupCode NVARCHAR(10) = NULL,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug BIT = 0
AS
BEGIN
    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());
    /*
    EXEC warehouse.PopulatePPXwalk
    */
    /* 
    Purpose - generate a comprehensive xwalk for any Pay plan which includes the following Key fields
        GS_SES_PayPlan,
        GS_SES_GradeLevel,
        GS_SES_SubgroupCode,
        GS_SES_LocationID,

        Target_PayPlan,
        Target_GradeLevel,
        Target_Subgroupcode,
        Target_Locationid,

        The above is then used via a self join outside of the this proceedure to map any given instance of a position to any of the other pay plans
    Explanation of steps

    ** The following is for non-CCE only
    1) equate gs/ses to all others at the subgroup level
    2) add in grade level equivalents
    3) add in location equivalents

    ** now CCE
    4) add in the CCE salary based equating
    */

    DECLARE @LatestAmcosVersionId AS INT;
    SET @LatestAmcosVersionId =
    (
        SELECT MAX(AmcosVersionId)FROM lookup.AMCOSVersion
    );

    IF @Debug = 1
    BEGIN
        PRINT 'Begin TRUNCATE TABLE warehouse.PPXwalk';
    END;

    /* This is a warehouse table so we start over each time */
    TRUNCATE TABLE warehouse.PPXwalk;

    IF @Debug = 1
    BEGIN
        PRINT 'End TRUNCATE TABLE warehouse.PPXwalk';
    END;

    /* get only the valid cost scenarios we have so we don't create unnecessary xwalk scenarios that won't produce costs in the end anyways */
    DROP TABLE IF EXISTS #uniquecosts;
    SELECT DISTINCT
           PayPlan,
           CategorySubgroupCode,
           GradeLevel,
           LocationId
    INTO #uniquecosts
    FROM data.Costs
    WHERE @LatestAmcosVersionId = AmcosVersionId
          AND CategorySubgroupCode <> '-1';

    --    if @debug=1 
    --  begin
    --  select '#uniquecosts'
    --	select * from #uniquecosts
    --end

    /* Step 1 */
    DROP TABLE IF EXISTS #GS;
    SELECT DISTINCT
           PayPlan AS GS_SES_PayPlan,
           GradeLevel AS GS_SES_GradeLevel,
           CategorySubgroupCode AS GS_SES_Subgroupcode,
           LocationId AS GS_SES_Locationid
    INTO #GS
    FROM #uniquecosts
    WHERE (
              PayPlan = 'SES'
              OR
              (
                  PayPlan = 'GS'
                  AND LocationId <> -1
              )
          );

    IF @Debug = 1
    BEGIN
        SELECT '#GS';
        SELECT *
        FROM #GS;
    END;

    --bring in PP to the ONET table
    DROP TABLE IF EXISTS #onet_withpp;
    SELECT DISTINCT
           a.ONET_code,
           a.SubgroupCode,
           b.PayPlan
    INTO #onet_withpp
    FROM xwalk.OnetSubgroupCrosswalk AS a
        INNER JOIN xwalk.PayPlanType AS b
            ON b.PayPlanType = a.PayPlanType
    WHERE @LatestAmcosVersionId
          BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
          AND
          (
              @CategorySubgroupCode IS NULL
              OR @CategorySubgroupCode = ''
              OR a.SubgroupCode = @CategorySubgroupCode
          ); --this allows us to test a specific subgroup

    IF @Debug = 1
    BEGIN
        SELECT '#onet_withpp';
        SELECT *
        FROM #onet_withpp;
    END;

    --filter our ONET table to only costs that exist
    DROP TABLE IF EXISTS #onet_final;
    SELECT DISTINCT
           a.ONET_code,
           a.SubgroupCode,
           a.PayPlan
    INTO #onet_final
    FROM #onet_withpp AS a
        INNER JOIN
        (SELECT DISTINCT CategorySubgroupCode, PayPlan FROM #uniquecosts) AS b
            ON a.SubgroupCode = b.CategorySubgroupCode
               AND a.PayPlan = b.PayPlan;

    IF @Debug = 1
    BEGIN
        SELECT '#onet_final';
        SELECT *
        FROM #onet_final;
    END;

    --now join the GS temp table to our xwalk
    DROP TABLE IF EXISTS #GS_subgroup;
    SELECT a.*,
           b.toPayPlan,
           b.ToSubgroupcode
    INTO #GS_subgroup
    FROM #GS AS a
        INNER JOIN
        (
            --first do a self join so we have the left and right AMCOS PP sides with the ONET as the 'crease' in the middle
            SELECT *
            FROM
            (
                SELECT ONET_code AS fromONET,
                       SubgroupCode AS GS_SES_subgroupcode,
                       PayPlan AS GS_SES_Payplan
                FROM #onet_final AS a
                WHERE PayPlan IN ( 'SES', 'GS' )
            ) AS GS_SES_subgroup_xwalk
                INNER JOIN
                (
                    SELECT ONET_code AS ToONET,
                           SubgroupCode AS ToSubgroupcode,
                           PayPlan AS toPayPlan
                    FROM #onet_final
                ) AS subgroup_xwalk
                    ON GS_SES_subgroup_xwalk.fromONET = subgroup_xwalk.ToONET
        ) AS b
            ON b.GS_SES_subgroupcode = a.GS_SES_Subgroupcode
               AND a.GS_SES_PayPlan = b.GS_SES_Payplan;

    IF @Debug = 1
    BEGIN
        SELECT '#GS_subgroup';
        SELECT *
        FROM #GS_subgroup;
    END;

    --## Step 2, add in the grade level cross walk
    DROP TABLE IF EXISTS #Gradelevel;
    SELECT DISTINCT
           GS_SES_Payplan,
           GS_SES_Gradelevel,
           ToPayPlan,
           ToGradeLevelPayBand,
           Strl AS ToSTRL
    INTO #Gradelevel
    FROM xwalk.PPXwalkGradeLevel AS a;

    IF @Debug = 1
    BEGIN
        SELECT '#Gradelevel';
        SELECT *
        FROM #Gradelevel;
    END;

    --advance subgrp by adding in now the grade level
    DROP TABLE IF EXISTS #GS_Subgroup_GL;
    SELECT a.*,
           b.ToGradeLevelPayBand,
           b.ToSTRL
    INTO #GS_Subgroup_GL
    FROM #GS_subgroup AS a
        INNER JOIN #Gradelevel AS b
            ON a.GS_SES_PayPlan = b.GS_SES_Payplan
               AND a.GS_SES_GradeLevel = b.GS_SES_Gradelevel
               AND a.toPayPlan = b.ToPayPlan;

    IF @Debug = 1
    BEGIN
        SELECT '#GS_Subgroup_GL';
        SELECT *
        FROM #GS_Subgroup_GL;
    END;


    --## Step 3, add in the location equivalent
    --link GS locality

    --start with all active GS locations
    DROP TABLE IF EXISTS #GSFIPS;
    SELECT a.LocationId AS gs_locationid,
           d.StateCode + d.CountyCode AS gs_FIPS
    INTO #GSFIPS
    FROM #uniquecosts AS a
        INNER JOIN warehouse.Location AS B
            ON B.LocationId = a.LocationId
        INNER JOIN PaySchedule.LocalityPay AS c
            ON B.SourceSystemCode = c.LocalityCode
        INNER JOIN xwalk.LocalityPayAreaToFips AS d
            ON d.LocalityCode = c.LocalityCode
    WHERE @LatestAmcosVersionId = c.AmcosVersionId
          AND @LatestAmcosVersionId = d.AmcosVersionId
          AND B.LocationType = 'Locality Pay Area'
    UNION
    --RUS locations which are not in the xwalk table
    SELECT DISTINCT
           a.LocationId AS gs_locationid,
           C.FIPSCode AS gs_FIPS
    FROM #uniquecosts AS a
        INNER JOIN warehouse.Location AS B
            ON B.LocationId = a.LocationId
        CROSS JOIN lookup.FIPS_ZIP AS C
    WHERE @LatestAmcosVersionId
          BETWEEN C.AmcosVersionIdStart AND C.AmcosVersionIdEnd
          AND B.LocationType = 'Locality Pay Area'
          AND B.SourceSystemCode = 'RUS'
          AND C.FIPSCode NOT IN
              (
                  --we want any FIPS that isn't attached to a specific locality area
                  SELECT StateCode + CountyCode
                  FROM xwalk.LocalityPayAreaToFips
                  WHERE @LatestAmcosVersionId
                  BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    --SELECT * FROM #GSFIPS WHERE gs_locationid=1837
    --SELECT * FROM warehouse.PPXwalk WHERE TargetPayPlan='GS' AND TargetSubgroupCode='1515' AND TargetLocationID=1837

    DROP TABLE IF EXISTS #GSLoc_Xwalk_inital;

    --AF wage first
    SELECT DISTINCT
           a.gs_locationid,
           c.LocationId AS xwalk_locationid,
           d.PayPlan AS targetpayplan
    INTO #GSLoc_Xwalk_inital
    FROM #GSFIPS AS a
        INNER JOIN xwalk.WageAreaToFips AS b
            ON a.gs_FIPS = CONCAT(b.StateCode, b.CountyCode)
        INNER JOIN warehouse.Location AS c
            ON b.ScheduleArea = c.SourceSystemCode
        CROSS JOIN
        (SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage AF') AS d
    WHERE b.FundType = 'AF'
          AND c.LocationType = 'Federal Wage System AF'
          AND @LatestAmcosVersionId = b.AmcosVersionId
    UNION
    --next NAF wage
    SELECT DISTINCT
           a.gs_locationid,
           c.LocationId AS xwalk_locationid,
           d.PayPlan AS targetpayplan
    FROM #GSFIPS AS a
        INNER JOIN xwalk.WageAreaToFips AS b
            ON a.gs_FIPS = CONCAT(b.StateCode, b.CountyCode)
        INNER JOIN warehouse.Location AS c
            ON b.ScheduleArea = c.SourceSystemCode
        CROSS JOIN
        (SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Wage NAF') AS d
    WHERE b.FundType = 'NAF'
          AND c.LocationType = 'Federal Wage System NAF'
          AND @LatestAmcosVersionId = b.AmcosVersionId
    UNION
    --then opm special pay
    SELECT DISTINCT
           a.gs_locationid,
           c.LocationId AS xwalk_locationid,
           d.PayPlan AS targetpayplan
    FROM #GSFIPS AS a
        INNER JOIN xwalk.SpecialRateTablesByLocation AS b
            ON a.gs_FIPS = b.StateCode + b.CountyCode
        INNER JOIN warehouse.Location AS c
            ON b.LocationName + ', ' + b.State = c.SourceSystemCode
        CROSS JOIN
        (SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'SpecialPay') AS d
    WHERE c.LocationType = 'OPM Special Pay Locations'
          AND @LatestAmcosVersionId = b.AmcosVersionId
    UNION
    --then locality areas to themselves
    --then opm special pay
    SELECT DISTINCT
           a.gs_locationid,
           a.gs_locationid AS xwalk_locationid,
           b.PayPlan AS targetpayplan
    FROM #GSFIPS AS a
        INNER JOIN
        (SELECT DISTINCT LocationId, PayPlan FROM #uniquecosts) AS b
            ON a.gs_locationid = b.LocationId
    UNION
    --now do military
    SELECT DISTINCT
           a.gs_locationid,
           d.LocationId AS xwalk_locationid,
           e.PayPlan AS targetpayplan
    FROM #GSFIPS AS a
        INNER JOIN lookup.FIPS_ZIP AS b
            ON a.gs_FIPS = b.FIPSCode
        INNER JOIN xwalk.ZIPToMHA AS c
            ON b.ZIPCode = c.ZIPCode
        INNER JOIN warehouse.Location AS d
            ON d.SourceSystemCode = c.MHA
        CROSS JOIN
        (SELECT PayPlan FROM lookup.PayPlanTags WHERE Tag = 'Military') AS e
    WHERE d.LocationType = 'CONUS Military Housing Area'
          AND @LatestAmcosVersionId
          BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
          AND @LatestAmcosVersionId = c.AmcosVersionId;

    --now to account for SES we need to link the location of -1 to all  possible locations
    DROP TABLE IF EXISTS #GSLoc_Xwalk;



    --now we take care of SES which is -1 location id
    SELECT DISTINCT
           -1 AS gs_locationid,
           xwalk_locationid,
           targetpayplan
    INTO #GSLoc_Xwalk
    FROM #GSLoc_Xwalk_inital
    UNION
    SELECT -1,
           -1,
           'SES'
    UNION
    SELECT gs_locationid,
           xwalk_locationid,
           targetpayplan
    FROM #GSLoc_Xwalk_inital;



    ----and  ToSubgroupcode='1515'
    --SELECT * FROM 

    --now we finally do the location xwalk
    DROP TABLE IF EXISTS #GS_Subgroup_GL_location;
    SELECT DISTINCT
           a.*,
           b.xwalk_locationid
    INTO #GS_Subgroup_GL_location
    FROM #GS_Subgroup_GL AS a
        INNER JOIN #GSLoc_Xwalk AS b
            ON a.GS_SES_Locationid = b.gs_locationid
               AND a.toPayPlan = b.targetpayplan;

    --SELECT TOP 100 * FROM #GS_Subgroup_GL WHERE  GS_SES_PayPlan='SES'
    --SELECT TOP 100 *  FROM #GSLoc_Xwalk WHERE gs_locationid=-1
    --SELECT TOP 100 * FROM #GS_Subgroup_GL_location WHERE  toPayPlan='SES'
    --SELECT TOP 100 * FROM #GS_Subgroup_GL_location WHERE   GS_SES_PayPlan='SES'
    --SELECT * FROM #GS_Subgroup_GL_location WHERE toPayPlan='GS' and  ToSubgroupcode='1515'
    --EXEC warehouse.PopulatePPXwalk
    --SELECT * FROM #GS_Subgroup_GL_location WHERE  toPayPlan='AE'

    INSERT INTO warehouse.PPXwalk
    (
        GS_SES_BasePayPlan,
        GS_SES_BaseGradeLevel,
        GS_SES_BaseSubgroupCode,
        GS_SES_BaseLocationID,
        TargetPayPlan,
        TargetGradeLevel,
        TargetSubgroupCode,
        TargetLocationID,
        TargetSTRL
    )
    SELECT DISTINCT
           GS_SES_PayPlan,
           GS_SES_GradeLevel,
           GS_SES_Subgroupcode,
           GS_SES_Locationid,
           toPayPlan,
           ToGradeLevelPayBand,
           ToSubgroupcode,
           xwalk_locationid,
           ToSTRL
    FROM #GS_Subgroup_GL_location;

    --nearest neighbors for CCE
    --the goal here is to translate BLS OES percentile (CCE) to GS grade levels
    --this has to be done however at the subgroup level as different subgroups have different associations
    --e.g. an Admin position 50th would not have the same GS equivalence then say a Project Manager or Ops Research 50th percentile
    --the best way to make this association is by comparing salaries

    /*
    We do this in several steps:
    1) get GS costs
    2) get BLS costs
    3) create GS to BLS location xwalk
    4) link #1 and #2 by way of #3 and the subgroup xwalk

    */

    --############## 1 Get GS costs
    DROP TABLE IF EXISTS #GSCosts;

    SELECT PayPlan,
           CategorySubgroupCode,
           CategorySubgroupDescription,
           LocationId,
           Location_name,
           GradeLevel,
           SUM(Amount) AS basepay
    INTO #GSCosts
    FROM data.CostsWithDescriptions
    WHERE PayPlan = 'GS' --equating to GS only so filter out everything else
          AND AmcosVersionId = @LatestAmcosVersionId
          AND CategorySubgroupCode <> '-1' --no group, pp, or career program averages
          AND NumberOfDependents = -1 --no overseas since CCE/BLS OE is only U.S.
          AND LocationId <> -1 --no location averages, we only want location specific values
          AND CostElementId IN (   275,  --base pay
                                   4894, --base pay 2 for firefighters
                                   4856  --non-foreign cola, e.g. AK &  HI
                               )
    GROUP BY PayPlan,
             CategorySubgroupCode,
             CategorySubgroupDescription,
             LocationId,
             Location_name,
             GradeLevel;


    /* Step 2 Get BLS/CCE costs */
    IF @Debug = 1
    BEGIN
        PRINT 'Begin Step 2 Get BLS/CCE costs';
    END;

    DROP TABLE IF EXISTS #BLSCosts;
    SELECT SOC,
           MSACode,
           GradeLevel,
           --some values are max value on purpose to indicate that the BLS does not provide salary above a certain amount, we in turn convert that to the BLS' max salary
           CASE
               WHEN basepay = 9999999 THEN
               (
                   SELECT crunch.GetSingleValue('CCE', 'MaxPayFootnote', @LatestAmcosVersionId)
               )
               ELSE
                   basepay
           END AS basepay,
           AmcosVersionId
    INTO #BLSCosts
    FROM
    (
        SELECT SOC,
               MSACode,
               '10th' AS GradeLevel,
               [A_PCT10] AS basepay,
               AmcosVersionId
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE AmcosVersionId = @LatestAmcosVersionId
        UNION
        SELECT SOC,
               MSACode,
               '25th' AS GradeLevel,
               [A_PCT25] AS basepay,
               AmcosVersionId
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE AmcosVersionId = @LatestAmcosVersionId
        UNION
        SELECT SOC,
               MSACode,
               '50th' AS GradeLevel,
               [A_MEDIAN] AS basepay,
               AmcosVersionId
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE AmcosVersionId = @LatestAmcosVersionId
        UNION
        SELECT SOC,
               MSACode,
               '75th' AS GradeLevel,
               [A_PCT75] AS basepay,
               AmcosVersionId
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE AmcosVersionId = @LatestAmcosVersionId
        UNION
        SELECT SOC,
               MSACode,
               '90th' AS GradeLevel,
               [A_PCT90] AS basepay,
               AmcosVersionId
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE AmcosVersionId = @LatestAmcosVersionId
    ) AS a
    WHERE basepay <> -1; -- -1 indicates a wage estimate is not available and thus we can't use those records

    IF @Debug = 1
    BEGIN
        PRINT 'End Step 2 Get BLS/CCE costs';
    END;


    IF @Debug = 1
    BEGIN
        PRINT 'Begin Step 3:  Get GS to BLS xwalk';
    END;

    /* Step 3:  Get GS to BLS xwalk */
    /* We need to be able to equate an MSA (CCE) location to a GS locality location for our comparison */
    DROP TABLE IF EXISTS #XWalkLocalityToMSA;
    SELECT a.MSACode,
           d.LocationId
    INTO #XWalkLocalityToMSA
    FROM
    (
        SELECT DISTINCT
               a.MSACode,
               m.MSAName,
               CASE
                   WHEN c.LocalityCode IS NULL THEN
                       'RUS'
                   ELSE
                       c.LocalityCode
               END AS LocalityCode --anything that doesn't resolve to a locality area is assumed to be rest of US
        FROM xwalk.MetropolitanStatisticalAreaToFips AS a
            INNER JOIN lookup.MetropolitanStatisticalArea m
                ON m.AmcosVersionId = a.AmcosVersionId
                   AND m.MSACode = a.MSACode
            LEFT OUTER JOIN xwalk.LocalityPayAreaToFips AS b
                ON a.StateCode + a.CountyCode = b.StateCode + b.CountyCode
            LEFT OUTER JOIN PaySchedule.LocalityPay AS c
                ON b.LocalityCode = c.LocalityCode
        WHERE (
                  @LatestAmcosVersionId = a.AmcosVersionId
                  OR a.AmcosVersionIdStart IS NULL
              )
              AND
              (
                  @LatestAmcosVersionId = b.AmcosVersionId
                  OR b.AmcosVersionId IS NULL
              )
              AND
              (
                  @LatestAmcosVersionId = c.AmcosVersionId
                  OR c.AmcosVersionId IS NULL
              )
    ) AS a
        LEFT OUTER JOIN warehouse.Location AS d
            ON a.LocalityCode = d.SourceSystemCode;

    IF @Debug = 1
    BEGIN
        PRINT 'End Step 3:  Get GS to BLS xwalk';
    END;

    IF @Debug = 1
    BEGIN
        PRINT 'Begin now do GS special pay xwalk which is much easier since we have an immediate xwalk from one of the OPM special pay tables';
    END;

    /* now do GS special pay xwalk which is much easier since we have an immediate xwalk from one of the OPM special pay tables */
    INSERT INTO #XWalkLocalityToMSA
    (
        MSACode,
        LocationId
    )
    SELECT DISTINCT
           c.MSACode,
           b.LocationId
    FROM xwalk.SpecialRateTablesByLocation AS a
        INNER JOIN warehouse.Location AS b
            ON a.LocationName + ', ' + a.[State] = b.SourceSystemCode
        INNER JOIN xwalk.MetropolitanStatisticalAreaToFips AS c
            ON c.StateCode + c.CountyCode = a.StateCode + a.CountyCode
    WHERE b.LocationType = 'OPM Special Pay Locations'
          --see warehouse.updateloctionid for the following 'handling' code as well as the naming convention above using a comma, we just need to replicate that here to complete the match
          AND a.StateCode <> 'X'
          AND a.CountyCode <> 'X'
          AND a.CityCode <> 'X'
          AND @LatestAmcosVersionId = a.AmcosVersionId
          AND @LatestAmcosVersionId
          BETWEEN c.AmcosVersionIdStart AND c.AmcosVersionIdEnd;

    IF @Debug = 1
    BEGIN
        PRINT 'End now do GS special pay xwalk which is much easier since we have an immediate xwalk from one of the OPM special pay tables';
    END;


    IF @Debug = 1
    BEGIN
        PRINT 'Begin step 4:  Link the costs together and insert them into our table';
    END;

    /* Step 4:  Link the costs together and insert them into our table */
    INSERT INTO warehouse.PPXwalk
    (
        GS_SES_BasePayPlan,
        GS_SES_BaseGradeLevel,
        GS_SES_BaseSubgroupCode,
        GS_SES_BaseLocationID,
        TargetPayPlan,
        TargetGradeLevel,
        TargetSubgroupCode,
        TargetLocationID,
        TargetSTRL
    )
    SELECT DISTINCT
           b.PayPlan AS BasePayPlan,
           b.GradeLevel AS BaseGradeLevel,
           b.CategorySubgroupCode AS BaseSubgroupCode,
           b.LocationId AS BaseLocationId,
           'CCE' AS TargetPayPlan,
           c.GradeLevel AS TargetGradeLevel,
           c.SOC AS TargetSubgroupCode,
           e.LocationId AS TargetLocationId,
           'Not Applicable' AS TargetStrl
    FROM #XWalkLocalityToMSA AS a
        INNER JOIN #GSCosts AS b
            ON b.LocationId = a.LocationId
        INNER JOIN #BLSCosts AS c
            ON c.MSACode = a.MSACode
        INNER JOIN xwalk.OnetSubgroupCrosswalk AS d
            ON d.ONetCodeTrimmed = c.SOC
               AND d.SubgroupCode = b.CategorySubgroupCode
        INNER JOIN warehouse.Location AS e
            ON e.SourceSystemCode = c.MSACode
    WHERE (@LatestAmcosVersionId)
          BETWEEN d.AmcosVersionIdStart AND d.AmcosVersionIdEnd
          AND e.LocationType = 'MSA'
          AND b.basepay / c.basepay
          BETWEEN .7 AND 1.3 --the GS schedule from step 1 to 10 is 30 percent in most cases so we use that as a mark on the wall to produce our range
                             --the range is high and thus we can expect something like this: GS Grade level 10 = 25th and 50th percentile but it would exclude say 90th, 75th and 10th which at least helps
                             --narrow things down for the user
          AND d.PayPlanType = 'CIV'; --no military links, just GS

    IF @Debug = 1
    BEGIN
        PRINT 'End step 4:  Link the costs together and insert them into our table';
    END;

END;
GO
