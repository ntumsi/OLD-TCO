




/*
Construct percent at ETS for AE only 
This is basically the percent of personnel by some aggregation (in this case YOS) of those within 12 months
of the expiration of their term of service (ETS)

There are two DMDC files we could use: ETS_Population and ETS_Rates, rates are at a very low level and lacks 
percent totals at our desired aggregation level so we need to use population and construct the appropriate
percentage.
*/

CREATE VIEW [data].[PercentAtETS_AvgReEnlistedRates]
AS
SELECT CONVERT(INT, a.yos) AS yos,
       a.pecatets,
       b.avgreenlistedrates
FROM
(
    SELECT yos,
           PercAtETS AS pecatets
    FROM
    (
        SELECT PayPlan,
               yos,
               pt.[<12],
               pt.[>12],
               pt.[<12] / NULLIF(pt.[>12] + pt.[<12], 0) AS PercAtETS
        FROM
        (
            --- !!! Run between these lines first to make sure the totals are what you expect
            SELECT PayPlan,
                   METS,
                   yos,
                   SUM(PercAtETS) AS PercAtETS
            FROM
            (
                SELECT PayPlan,
                       CMF,
                       GradeLevel,
                       AccessionQuality,
                       METS,
                       RIGHT(YOS, LEN(YOS) - CHARINDEX('_', YOS)) AS yos,
                       PercAtETS
                FROM [DMDC].[ETS_Population] ETS_Population
                    UNPIVOT
                    (
                        PercAtETS
                        FOR [YOS] IN ([YOS_0], [YOS_1], [YOS_2], [YOS_3], [YOS_4], [YOS_5], [YOS_6], [YOS_7], [YOS_8],
                                      [YOS_9], [YOS_10], [YOS_11], [YOS_12], [YOS_13], [YOS_14], [YOS_15], [YOS_16],
                                      [YOS_17], [YOS_18], [YOS_19], [YOS_20], [YOS_21], [YOS_22], [YOS_23], [YOS_24],
                                      [YOS_25], [YOS_26], [YOS_27], [YOS_28], [YOS_29], [YOS_30], [YOS_31], [YOS_32],
                                      [YOS_33], [YOS_34], [YOS_35], [YOS_36], [YOS_37], [YOS_38], [YOS_39], [YOS_40],
                                      [YOS_GreaterThan40], [YOS_Unknown]
                                     )
                    ) unpt
            ) AS a
            WHERE AccessionQuality = 3
                  AND GradeLevel = 20
                  AND PayPlan = 'AE'
                  AND CMF <= 99 --you can use the non-totals or the totals for aggregation but we need to filter out one to avoid dobule counting, i chose to use totals

            GROUP BY PayPlan,
                     METS,
                     yos
        --- !!! Run between these lines first to make sure thr totals are what you expect
        ) AS a
        PIVOT
        (
            SUM(PercAtETS)
            FOR [METS] IN ([<12], [>12])
        ) AS pt
    ) AS b
) AS a
    FULL OUTER JOIN
    (
        --construct Average Re-enlistment rates 
        --this is basically the percent of personnel by some aggregation (in this case YOS) of those who re-enlist (same as continuation rate)
        --this is so simple but its not all that intuitive at first glance
        --we believe the original table expects to see the percent of people within 12 months of ETS who re-enlist, NOT everyone who re-enlists
        --the explanation in the DMDC query says that the rate data is the rate of those in the ETS group who re-enlist
        --since we only want those who re-enlist within 12mo of ETS we can simply pull just those rate values in the aggregate and be done with it

        -- Combine the 2 ETS querries
        SELECT a.PayPlan,
               a.CMF,
               a.GradeLevel,
               a.AccessionQuality,
               a.METS,
               a.yos,
               a.METSReEnlistedRates,
               b.[<12],
               b.[>12],
               b.[<12] + b.[>12] AS totalPop,
               (a.METSReEnlistedRates / 100 * b.[<12]) / NULLIF((b.[<12] + b.[>12]), 0) AS avgreenlistedrates
        --note the calculation, we are taking the rate, converting it to a decimal, multiplying it by the <12 pop and then taking that result and dividing it into the total pop
        --this gives us the percent who re-enlisted within that YOS where their METS <12
        FROM
        (

            --- !!! Grab just the rates for those who re-enlist within 12mo of ETS
            SELECT a.PayPlan,
                   a.CMF,
                   a.GradeLevel,
                   a.AccessionQuality,
                   a.METS,
                   a.yos,
                   a.METSReEnlistedRates
            FROM
            (
                SELECT PayPlan,
                       CMF,
                       GradeLevel,
                       AccessionQuality,
                       METS,
                       RIGHT(YOS, LEN(YOS) - CHARINDEX('_', YOS)) AS yos,
                       METSReEnlistedRates
                FROM [DMDC].[ETS_Rates] ETS_Rates
                    UNPIVOT
                    (
                        METSReEnlistedRates
                        FOR [YOS] IN ([YOS_0], [YOS_1], [YOS_2], [YOS_3], [YOS_4], [YOS_5], [YOS_6], [YOS_7], [YOS_8],
                                      [YOS_9], [YOS_10], [YOS_11], [YOS_12], [YOS_13], [YOS_14], [YOS_15], [YOS_16],
                                      [YOS_17], [YOS_18], [YOS_19], [YOS_20], [YOS_21], [YOS_22], [YOS_23], [YOS_24],
                                      [YOS_25], [YOS_26], [YOS_27], [YOS_28], [YOS_29], [YOS_30], [YOS_31], [YOS_32],
                                      [YOS_33], [YOS_34], [YOS_35], [YOS_36], [YOS_37], [YOS_38], [YOS_39], [YOS_40],
                                      [YOS_GreaterThan40], [YOS_Unknown]
                                     )
                    ) unpt
            ) AS a
            WHERE AccessionQuality = 3
                  AND GradeLevel = 20
                  AND PayPlan = 'AE'
                  AND CMF = 104
                  AND METS = '<12' --we need just the MOS totals

        --join part
        ) AS a
            FULL OUTER JOIN
            (

                --- Get the population of each METS group
                SELECT pt.PayPlan,
                       pt.CMF,
                       pt.GradeLevel,
                       pt.AccessionQuality,
                       pt.yos,
                       pt.[>12],
                       pt.[<12]
                FROM
                (
                    SELECT a.PayPlan,
                           a.CMF,
                           a.GradeLevel,
                           a.AccessionQuality,
                           a.METS,
                           a.yos,
                           a.pop
                    FROM
                    (
                        SELECT PayPlan,
                               CMF,
                               GradeLevel,
                               AccessionQuality,
                               METS,
                               RIGHT(YOS, LEN(YOS) - CHARINDEX('_', YOS)) AS yos,
                               pop
                        FROM [DMDC].[ETS_Population] ETS_Population
                            UNPIVOT
                            (
                                pop
                                FOR [YOS] IN ([YOS_0], [YOS_1], [YOS_2], [YOS_3], [YOS_4], [YOS_5], [YOS_6], [YOS_7],
                                              [YOS_8], [YOS_9], [YOS_10], [YOS_11], [YOS_12], [YOS_13], [YOS_14],
                                              [YOS_15], [YOS_16], [YOS_17], [YOS_18], [YOS_19], [YOS_20], [YOS_21],
                                              [YOS_22], [YOS_23], [YOS_24], [YOS_25], [YOS_26], [YOS_27], [YOS_28],
                                              [YOS_29], [YOS_30], [YOS_31], [YOS_32], [YOS_33], [YOS_34], [YOS_35],
                                              [YOS_36], [YOS_37], [YOS_38], [YOS_39], [YOS_40], [YOS_GreaterThan40],
                                              [YOS_Unknown]
                                             )
                            ) unpt
                    ) AS a
                    WHERE AccessionQuality = 3
                          AND GradeLevel = 20
                          AND PayPlan = 'AE'
                          AND CMF = 104
                ) AS a
                PIVOT
                (
                    MAX(pop)
                    FOR [METS] IN ([<12], [>12])
                ) AS pt


            --METS rate and pop join
            ) AS b
                ON a.CMF = b.CMF
                   AND a.PayPlan = b.PayPlan
                   AND a.GradeLevel = b.GradeLevel
                   AND a.AccessionQuality = b.AccessionQuality
                   AND a.yos = b.yos

    --master join from above

    ) AS b
        ON a.yos = b.yos
WHERE a.yos <> 'GreaterThan40'
      AND a.yos <> 'Unknown';