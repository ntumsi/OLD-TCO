





CREATE VIEW [data].[ContinuationRates]
AS

--This query pulls together data from various DMDC tables to generate the continuation rates for all military pay plans

--#### uncomment between these lines to check for dups prior to going final
--select payplan, CMF, YOS, count(continuation_rate) from (
--#### end of header for dup check, don't forget dup check footer

--###BEGIN THE COMBINATION PROCESS#####--
SELECT PayPlan,
       CMF,
       YOS,
       Continuation_Rate AS ContinuationRate
FROM
(

    --Let's start with the Active military enlisted continaution rates

    --let's do some filtering on the data and processing
    --99 CMF is unknown and the code expects ZZ so we need to convert to what the code expects
    SELECT PayPlan,
           CASE
               WHEN CMF = '99' THEN
                   'ZZ'
               ELSE
                   CMF
           END AS CMF,
           RIGHT(YOS, LEN(YOS) - 3) AS YOS,
           (NotPromoted_Rate + Promoted_Rate) / 100 AS Continuation_Rate
    FROM
    (

        --pull together the promoted, notpromoted and populaiton data so we can fully analyze
        --this DMDC data
        SELECT a.NotPromoted_Rate,
               a.YOS,
               a.AccessionQuality,
               a.GradeLevel,
               a.GradeType,
               a.CMF,
               a.PayPlan,
               a.Promoted_Rate,
               b.Pop
        FROM
        (
            SELECT a.PayPlan,
                   a.CMF,
                   a.GradeType,
                   a.GradeLevel,
                   a.AccessionQuality,
                   a.YOS,
                   a.NotPromoted_Rate,
                   b.Promoted_Rate
            FROM
            (

                --Pivot the not promoted rates so we can do some processing
                SELECT PayPlan,
                       CMF,
                       GradeType,
                       GradeLevel,
                       AccessionQuality,
                       YOS,
                       NotPromoted_Rate
                FROM [DMDC].[ContinuationRates_NotPromoted] ContinuationRates_NotPromoted
                    UNPIVOT
                    (
                        NotPromoted_Rate
                        FOR [YOS] IN ([YOS0], [YOS1], [YOS2], [YOS3], [YOS4], [YOS5], [YOS6], [YOS7], [YOS8], [YOS9],
                                      [YOS10], [YOS11], [YOS12], [YOS13], [YOS14], [YOS15], [YOS16], [YOS17], [YOS18],
                                      [YOS19], [YOS20], [YOS21], [YOS22], [YOS23], [YOS24], [YOS25], [YOS26], [YOS27],
                                      [YOS28], [YOS29], [YOS30], [YOS31], [YOS32], [YOS33], [YOS34], [YOS35], [YOS36],
                                      [YOS37], [YOS38], [YOS39], [YOS40] --,[YOS_GreaterThan40],[YOS_Unknown],[YOS_Total] - AMCOS does not use these so we dropp them
                                     )
                    ) piv
            ) AS a
                FULL OUTER JOIN
                (
                    --Pivot the  promoted rates so we can do some processing
                    SELECT PayPlan,
                           CMF,
                           GradeType,
                           GradeLevel,
                           AccessionQuality,
                           YOS,
                           Promoted_Rate
                    FROM [DMDC].[ContinuationRates_Promoted] ContinuationRates_Promoted
                        UNPIVOT
                        (
                            Promoted_Rate
                            FOR [YOS] IN ([YOS0], [YOS1], [YOS2], [YOS3], [YOS4], [YOS5], [YOS6], [YOS7], [YOS8],
                                          [YOS9], [YOS10], [YOS11], [YOS12], [YOS13], [YOS14], [YOS15], [YOS16],
                                          [YOS17], [YOS18], [YOS19], [YOS20], [YOS21], [YOS22], [YOS23], [YOS24],
                                          [YOS25], [YOS26], [YOS27], [YOS28], [YOS29], [YOS30], [YOS31], [YOS32],
                                          [YOS33], [YOS34], [YOS35], [YOS36], [YOS37], [YOS38], [YOS39], [YOS40] --,[YOS_GreaterThan40],[YOS_Unknown],[YOS_Total] - AMCOS does not use these so we dropp them
                                         )
                        ) piv
                ) AS b
                    --make sure the join does unique records

                    ON a.PayPlan = b.PayPlan
                       AND a.CMF = b.CMF
                       AND a.GradeType = b.GradeType
                       AND a.GradeLevel = b.GradeLevel
                       AND a.AccessionQuality = b.AccessionQuality
                       AND a.YOS = b.YOS
        ) AS a
            FULL OUTER JOIN
            (
                SELECT PayPlan,
                       CMF,
                       GradeType,
                       GradeLevel,
                       AccessionQuality,
                       YOS,
                       Pop
                FROM [DMDC].BasePopulation BasePopulation
                    UNPIVOT
                    (
                        Pop
                        FOR [YOS] IN ([YOS0], [YOS1], [YOS2], [YOS3], [YOS4], [YOS5], [YOS6], [YOS7], [YOS8], [YOS9],
                                      [YOS10], [YOS11], [YOS12], [YOS13], [YOS14], [YOS15], [YOS16], [YOS17], [YOS18],
                                      [YOS19], [YOS20], [YOS21], [YOS22], [YOS23], [YOS24], [YOS25], [YOS26], [YOS27],
                                      [YOS28], [YOS29], [YOS30], [YOS31], [YOS32], [YOS33], [YOS34], [YOS35], [YOS36],
                                      [YOS37], [YOS38], [YOS39], [YOS40] --,[YOS_GreaterThan40],[YOS_Unknown],[YOS_Total] - AMCOS does not use these so we dropp them
                                     )
                    ) piv
            ) AS b
                ON a.PayPlan = b.PayPlan
                   AND a.CMF = b.CMF
                   AND a.GradeType = b.GradeType
                   AND a.GradeLevel = b.GradeLevel
                   AND a.AccessionQuality = b.AccessionQuality
                   AND a.YOS = b.YOS
    ) AS a
    --now we need to do some filtering on the data
    WHERE GradeLevel = '20' --we just want the total by grade level, DMDC says gradelevel 20 are totals
          AND AccessionQuality = '3' -- we don't care about accession quality, DMDC says accession qulity 3 are totals
          AND Pop > 0 --if there is no population then we can't have a continuation rate so filter those out
          --if we didn't they would say 0 continuation rate which is incorrect and misleading
          AND PayPlan = 'AE' -- other PayPlan data comes from elsewhere so let's just pull AE
          AND CMF < 100 --CMFs above 99 are totals
    --order by payplan, CMF, YOS


    --####END AE QUERY#####----


    UNION

    --Next up are the reserve continuation rates which come from a different table

    SELECT PayPlan,
           CMF,
           YOS,
           --, inventory
           --,cont_pop
           cont_pop / inventory AS cont_rate
    FROM
    (

        --conduct the aggregation to the 2 digit CMF level
        SELECT PayPlan,
               cmf2 AS CMF,
               YOS,
               SUM(inventory) AS inventory,
               SUM(cont_pop) AS cont_pop
        FROM
        (

            --pull the inventory and cont rate querries together and create a continuation rate population count so we can prepare to sum and then computer an aggregated cont rate
            SELECT a.PayPlan,
                   a.CMF,
                   a.YOS,
                   a.Continuation_Rate,
                   LEFT(a.CMF, 2) AS cmf2,
                   b.inventory,
                   b.inventory * (a.Continuation_Rate / 100) AS cont_pop
            FROM
            (

                --This table already has the data as continuation rates so we need some slight processing
                SELECT PayPlan,
                       MOS AS CMF, --NOTE, AMCOS only uses the 2 character MOS but for reserve 3 are available, need to fix that eventually
                       RIGHT(YOS, LEN(YOS) - 3) AS YOS,
                       Continuation_Rate
                FROM [DMDC].[RAR2409] RAR2409
                    UNPIVOT
                    (
                        Continuation_Rate
                        FOR [YOS] IN ([YOS0], [YOS1], [YOS2], [YOS3], [YOS4], [YOS5], [YOS6], [YOS7], [YOS8], [YOS9],
                                      [YOS10], [YOS11], [YOS12], [YOS13], [YOS14], [YOS15], [YOS16], [YOS17], [YOS18],
                                      [YOS19], [YOS20], [YOS21], [YOS22], [YOS23], [YOS24], [YOS25], [YOS26], [YOS27],
                                      [YOS28], [YOS29], [YOS30], [YOS31], [YOS32], [YOS33], [YOS34], [YOS35], [YOS36],
                                      [YOS37], [YOS38], [YOS39], [YOS40] --,[YOS_GreaterThan40],[YOS_Unknown] - AMCOS does not use these so we dropp them
                                     )
                    ) piv
                WHERE PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
            ) AS a
                LEFT OUTER JOIN
                (
                    --prepare the inventory query where we sum and group by CMF and payplan

                    SELECT [PayPlan],
                           [CategorySubGroupCode] AS CMF,
                           --,[GradeType]
                           --,[GradeLevel]
                           [Step_YOS],
                           SUM([Inventory]) AS inventory
                    FROM [data].[Inventory]
                    WHERE PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' )
                    GROUP BY PayPlan,
                             [CategorySubGroupCode],
                             [Step_YOS]
                ) AS b
                    ON a.PayPlan = b.PayPlan
                       AND a.CMF = b.CMF
                       AND a.YOS = b.Step_YOS
        --order by payplan, CMF, YOS
        ) AS a
        WHERE inventory > 0 --if we have no inventory then we can't have a continuation rate

        GROUP BY PayPlan,
                 cmf2,
                 YOS
    --order by payplan, CMF, YOS
    ) AS a
    --order by payplan, CMF, YOS

    UNION

    --Now we need to pull the ZZ reserve continuation rates together which require minimal processing and do not need inventory to compute them since no aggregation is required

    SELECT PayPlan,
           LEFT(MOS, 2) AS CMF, --NOTE, AMCOS only uses the 2 character MOS but for reserve 3 are available, need to fix that eventually
           RIGHT(YOS, LEN(YOS) - 3) AS YOS,
           Continuation_Rate / 100 AS Continuation_Rate
    FROM [DMDC].[RAR2409] RAR2409
        UNPIVOT
        (
            Continuation_Rate
            FOR [YOS] IN ([YOS0], [YOS1], [YOS2], [YOS3], [YOS4], [YOS5], [YOS6], [YOS7], [YOS8], [YOS9], [YOS10],
                          [YOS11], [YOS12], [YOS13], [YOS14], [YOS15], [YOS16], [YOS17], [YOS18], [YOS19], [YOS20],
                          [YOS21], [YOS22], [YOS23], [YOS24], [YOS25], [YOS26], [YOS27], [YOS28], [YOS29], [YOS30],
                          [YOS31], [YOS32], [YOS33], [YOS34], [YOS35], [YOS36], [YOS37], [YOS38], [YOS39], [YOS40] --,[YOS_GreaterThan40],[YOS_Unknown] - AMCOS does not use these so we dropp them
                         )
        ) piv
    WHERE MOS = 'ZZZZ'

    ---##### END RESERVE QUERY #####---


    UNION

    --Officer continuation rates
    --Grade 11 through 15 = W1 through W5
    --Grade 21 through 30 = O1 through O10 
    --Grade 32 is total warrant and officer (summary level)
    --CMF of 99 is unknown (ZZ)
    --CMF of 100 is total for MOS (summary level)

    SELECT 'AO' AS PayPlan,
           ao.CMF,
           ao.YOS,
           ao.namt
    FROM
    (
        SELECT CMF,
               YOS,
               cont_pop / NULLIF(pop, 0) AS namt
        FROM
        (
            SELECT CMF,
                   YOS,
                   SUM(population) AS pop,
                   SUM(cont_pop) AS cont_pop
            FROM
            (
                SELECT CASE
                           WHEN CMF = '99' THEN
                               'ZZ'
                           ELSE
                               CMF
                       END AS CMF,
                       [GradeLevel],
                       [YOS],
                       [Inventory],
                       [Cont_Rate_All],
                       [Cont_Rate_Promoted],
                       CAST(Inventory AS INTEGER) AS population,
                       (CAST(Cont_Rate_All AS FLOAT) + CAST(Cont_Rate_Promoted AS FLOAT)) / 100
                       * CAST(Inventory AS INTEGER) AS cont_pop
                FROM [DMDC].[OFBYPMOS]
                --Grade 21 through 30 = O1 through O10 
                WHERE GradeLevel IN ( 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 )
                      AND CMF <> '100'
            ) AS a
            GROUP BY CMF,
                     YOS --order by mos, YOS
        ) AS b -- order by mos, YOS
    ) AS ao

    --#### END AO QUERY ####---


    UNION

    --Warrant Officer continuation rates
    --Grade 11 through 15 = W1 through W5
    --Grade 21 through 30 = O1 through O10 
    --Grade 32 is total warrant and officer (summary level)
    --CMF of 99 is unknown (ZZ)
    --CMF of 100 is total for MOS (summary level)

    SELECT 'AWO' AS PayPlan,
           awo.CMF,
           awo.YOS,
           awo.namt
    FROM
    (
        SELECT CMF,
               YOS,
               cont_pop / NULLIF(pop, 0) AS namt
        FROM
        (
            SELECT CMF,
                   YOS,
                   SUM(population) AS pop,
                   SUM(cont_pop) AS cont_pop
            FROM
            (
                SELECT CASE
                           WHEN CMF = '99' THEN
                               'ZZ'
                           ELSE
                               CMF
                       END AS CMF,
                       [GradeLevel],
                       [YOS],
                       [Inventory],
                       [Cont_Rate_All],
                       [Cont_Rate_Promoted],
                       CAST(Inventory AS INTEGER) AS population,
                       (CAST(Cont_Rate_All AS FLOAT) + CAST(Cont_Rate_Promoted AS FLOAT)) / 100
                       * CAST(Inventory AS INTEGER) AS cont_pop
                FROM [DMDC].[OFBYPMOS]
                --Grade 11 through 15 = W1 through W5 
                WHERE GradeLevel IN ( 11, 12, 13, 14, 15 )
                      AND CMF <> '100'
            ) AS a
            GROUP BY CMF,
                     YOS --order by mos, YOS
        ) AS b -- order by mos, YOS
    ) AS awo

--#### END AWO QUERY ####---

) AS a;
--where a.payplan='RO' and a.CMF='15' and a.YOS='10'
--order by CMF, YOS, payplan

--##### footer for dup check
--) as a group by payplan, CMF, YOS order by count(continuation_rate) desc
--##### end dup check footer