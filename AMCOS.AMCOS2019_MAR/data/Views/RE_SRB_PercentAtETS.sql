

CREATE VIEW [data].[RE_SRB_PercentAtETS]
AS
    SELECT PayPlan ,
           gradetype ,
           GradeLevel ,
           PercAtETS AS pecatets
    FROM   (   SELECT PayPlan ,
                      gradetype ,
                      GradeLevel ,
                      pt.[<12] ,
                      pt.[>12] ,
                      pt.[<12] / NULLIF(pt.[>12] + pt.[<12], 0) AS PercAtETS
               FROM   (
                          --- !!! Run between these lines first to make sure the totals are what you expect
                          SELECT   PayPlan ,
                                   gradetype ,
                                   GradeLevel ,
                                   METS ,
                                   SUM(PercAtETS) AS PercAtETS
                          FROM     (   SELECT CMF ,
                                              PayPlan ,
                                              'E' AS gradetype ,
                                              GradeLevel ,
                                              AccessionQuality ,
                                              METS ,
                                              PercAtETS
                                       FROM   [DMDC].[ETS_Population] UNPIVOT(PercAtETS FOR [YOS] IN([YOS_0], [YOS_1], [YOS_2], [YOS_3], [YOS_4], [YOS_5], [YOS_6], [YOS_7], [YOS_8], [YOS_9], [YOS_10], [YOS_11], [YOS_12], [YOS_13], [YOS_14], [YOS_15], [YOS_16], [YOS_17], [YOS_18], [YOS_19], [YOS_20], [YOS_21], [YOS_22], [YOS_23], [YOS_24], [YOS_25], [YOS_26], [YOS_27], [YOS_28], [YOS_29], [YOS_30], [YOS_31], [YOS_32], [YOS_33], [YOS_34], [YOS_35], [YOS_36], [YOS_37], [YOS_38], [YOS_39], [YOS_40], [YOS_GreaterThan40], [YOS_Unknown]))unpt
                                   ) AS a
                          WHERE    AccessionQuality <> 3
                                   AND GradeLevel <> 20
                                   AND PayPlan = 'AE'
                                   AND CMF <= 99
                          --you can use the non-totals or the totals for aggregation but we need to filter out one to avoid dobule counting, we need the detailed grades so i chose
                          --to filter out the totals and keep the details acc=3 are totals, gradelevel=20 are totals, mos>99 are totals

                          GROUP BY PayPlan ,
                                   METS ,
                                   gradetype ,
                                   GradeLevel
                      --- !!! Run between these lines first to make sure thr totals are what you expect
                      ) AS a
               PIVOT (   SUM(PercAtETS)
                         FOR [METS] IN ( [<12], [>12] )
                     ) AS pt
           ) AS b;