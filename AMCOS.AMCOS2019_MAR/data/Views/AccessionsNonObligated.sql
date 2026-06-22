

CREATE VIEW [data].[AccessionsNonObligated]
AS
    --Accessions Query

    -- non-obligations are obligation = 0
    -- obligations are all those other obligations (1 year through 9 years)
    -- this file has NE, NO, NWO, RE, RO and RWO PPs however the original AMCOS tables only refer to RE so there is a filter
    --later on to cut down this data to just RE, a future improvement for AMCOS will be to have the Reserve and NG crunch procs use their specific PP data
    --as opposed to this one size fits all approach

    --this file does not have summary elements so no filtering of a summary gradelevel is required

    --summarize the data (unfortunately for whatever reason this can't be done in the conversion step below so we need another select
    SELECT   PayPlan ,
             MOS ,
             GradeType ,
             GradeLevel ,
             Obligation ,
             SUM(Amount) AS Amount
    FROM     (
                 --convert the data into only ob/non ob instead of the varying degrees of Years of Obligation
                 SELECT PayPlan ,
                        [MOS] ,
                        [GradeType] ,
                        [GradeLevel] ,
                        CASE YrsOb
                             WHEN 0 THEN 'NonOB'
                             WHEN 1 THEN 'Ob'
                             WHEN 2 THEN 'Ob'
                             WHEN 3 THEN 'Ob'
                             WHEN 4 THEN 'Ob'
                             WHEN 5 THEN 'Ob'
                             WHEN 6 THEN 'Ob'
                             WHEN 7 THEN 'Ob'
                             WHEN 8 THEN 'Ob'
                             WHEN 9 THEN 'Ob'
                        END AS Obligation ,
                        Amount
                 FROM   (

                            --summarize the pivotted data
                            SELECT   PayPlan ,
                                     [MOS] ,
                                     [GradeType] ,
                                     [GradeLevel] ,
                                     RIGHT([YOS_Ob], 1) AS YrsOb ,
                                     SUM(Amount) AS Amount
                            FROM     (

                                         --let's process the tabmos file into one we can start to use by un-pivoting the columns into rows  
                                         SELECT PayPlan ,
                                                [MOS] ,
                                                [GradeType] ,
                                                [GradeLevel] ,
                                                [YOS_Ob] ,
                                                Amount
                                         FROM   [DMDC].[TABMOS] UNPIVOT(Amount FOR [YOS_Ob] IN([YOS0Obligation0], [YOS0Obligation1], [YOS0Obligation2], [YOS0Obligation3], [YOS0Obligation4], [YOS0Obligation5], [YOS0Obligation6], [YOS0Obligation7], [YOS0Obligation8], [YOS0Obligation9], [YOS1Obligation0], [YOS1Obligation1], [YOS1Obligation2], [YOS1Obligation3], [YOS1Obligation4], [YOS1Obligation5], [YOS1Obligation6], [YOS1Obligation7], [YOS1Obligation8], [YOS1Obligation9], [YOS2Obligation0], [YOS2Obligation1], [YOS2Obligation2], [YOS2Obligation3], [YOS2Obligation4], [YOS2Obligation5], [YOS2Obligation6], [YOS2Obligation7], [YOS2Obligation8], [YOS2Obligation9], [YOS3Obligation0], [YOS3Obligation1], [YOS3Obligation2], [YOS3Obligation3], [YOS3Obligation4], [YOS3Obligation5], [YOS3Obligation6], [YOS3Obligation7], [YOS3Obligation8], [YOS3Obligation9], [YOS4Obligation0], [YOS4Obligation1], [YOS4Obligation2], [YOS4Obligation3], [YOS4Obligation4], [YOS4Obligation5], [YOS4Obligation6], [YOS4Obligation7], [YOS4Obligation8], [YOS4Obligation9], [YOS5Obligation0], [YOS5Obligation1], [YOS5Obligation2], [YOS5Obligation3], [YOS5Obligation4], [YOS5Obligation5], [YOS5Obligation6], [YOS5Obligation7], [YOS5Obligation8], [YOS5Obligation9], [YOS6Obligation0], [YOS6Obligation1], [YOS6Obligation2], [YOS6Obligation3], [YOS6Obligation4], [YOS6Obligation5], [YOS6Obligation6], [YOS6Obligation7], [YOS6Obligation8], [YOS6Obligation9], [YOS7Obligation0], [YOS7Obligation1], [YOS7Obligation2], [YOS7Obligation3], [YOS7Obligation4], [YOS7Obligation5], [YOS7Obligation6], [YOS7Obligation7], [YOS7Obligation8], [YOS7Obligation9], [YOS8Obligation0], [YOS8Obligation1], [YOS8Obligation2], [YOS8Obligation3], [YOS8Obligation4], [YOS8Obligation5], [YOS8Obligation6], [YOS8Obligation7], [YOS8Obligation8], [YOS8Obligation9], [YOS9Obligation0], [YOS9Obligation1], [YOS9Obligation2], [YOS9Obligation3], [YOS9Obligation4], [YOS9Obligation5], [YOS9Obligation6], [YOS9Obligation7], [YOS9Obligation8], [YOS9Obligation9], [YOS10Obligation0], [YOS10Obligation1], [YOS10Obligation2], [YOS10Obligation3], [YOS10Obligation4], [YOS10Obligation5], [YOS10Obligation6], [YOS10Obligation7], [YOS10Obligation8], [YOS10Obligation9], [YOS11Obligation0], [YOS11Obligation1], [YOS11Obligation2], [YOS11Obligation3], [YOS11Obligation4], [YOS11Obligation5], [YOS11Obligation6], [YOS11Obligation7], [YOS11Obligation8], [YOS11Obligation9], [YOS12Obligation0], [YOS12Obligation1], [YOS12Obligation2], [YOS12Obligation3], [YOS12Obligation4], [YOS12Obligation5], [YOS12Obligation6], [YOS12Obligation7], [YOS12Obligation8], [YOS12Obligation9], [YOS13Obligation0], [YOS13Obligation1], [YOS13Obligation2], [YOS13Obligation3], [YOS13Obligation4], [YOS13Obligation5], [YOS13Obligation6], [YOS13Obligation7], [YOS13Obligation8], [YOS13Obligation9], [YOS14Obligation0], [YOS14Obligation1], [YOS14Obligation2], [YOS14Obligation3], [YOS14Obligation4], [YOS14Obligation5], [YOS14Obligation6], [YOS14Obligation7], [YOS14Obligation8], [YOS14Obligation9], [YOS15Obligation0], [YOS15Obligation1], [YOS15Obligation2], [YOS15Obligation3], [YOS15Obligation4], [YOS15Obligation5], [YOS15Obligation6], [YOS15Obligation7], [YOS15Obligation8], [YOS15Obligation9], [YOS16Obligation0], [YOS16Obligation1], [YOS16Obligation2], [YOS16Obligation3], [YOS16Obligation4], [YOS16Obligation5], [YOS16Obligation6], [YOS16Obligation7], [YOS16Obligation8], [YOS16Obligation9], [YOS17Obligation0], [YOS17Obligation1], [YOS17Obligation2], [YOS17Obligation3], [YOS17Obligation4], [YOS17Obligation5], [YOS17Obligation6], [YOS17Obligation7], [YOS17Obligation8], [YOS17Obligation9], [YOS18Obligation0], [YOS18Obligation1], [YOS18Obligation2], [YOS18Obligation3], [YOS18Obligation4], [YOS18Obligation5], [YOS18Obligation6], [YOS18Obligation7], [YOS18Obligation8], [YOS18Obligation9], [YOS19Obligation0], [YOS19Obligation1], [YOS19Obligation2], [YOS19Obligation3], [YOS19Obligation4], [YOS19Obligation5], [YOS19Obligation6], [YOS19Obligation7], [YOS19Obligation8], [YOS19Obligation9], [YOS20Obligation0], [YOS20Obligation1], [YOS20Obligation2], [YOS20Obligation3], [YOS20Obligation4], [YOS20Obligation5], [YOS20Obligation6], [YOS20Obligation7], [YOS20Obligation8], [YOS20Obligation9], [YOS21Obligation0], [YOS21Obligation1], [YOS21Obligation2], [YOS21Obligation3], [YOS21Obligation4], [YOS21Obligation5], [YOS21Obligation6], [YOS21Obligation7], [YOS21Obligation8], [YOS21Obligation9], [YOS22Obligation0], [YOS22Obligation1], [YOS22Obligation2], [YOS22Obligation3], [YOS22Obligation4], [YOS22Obligation5], [YOS22Obligation6], [YOS22Obligation7], [YOS22Obligation8], [YOS22Obligation9], [YOS23Obligation0], [YOS23Obligation1], [YOS23Obligation2], [YOS23Obligation3], [YOS23Obligation4], [YOS23Obligation5], [YOS23Obligation6], [YOS23Obligation7], [YOS23Obligation8], [YOS23Obligation9], [YOS24Obligation0], [YOS24Obligation1], [YOS24Obligation2], [YOS24Obligation3], [YOS24Obligation4], [YOS24Obligation5], [YOS24Obligation6], [YOS24Obligation7], [YOS24Obligation8], [YOS24Obligation9], [YOS25Obligation0], [YOS25Obligation1], [YOS25Obligation2], [YOS25Obligation3], [YOS25Obligation4], [YOS25Obligation5], [YOS25Obligation6], [YOS25Obligation7], [YOS25Obligation8], [YOS25Obligation9], [YOS26Obligation0], [YOS26Obligation1], [YOS26Obligation2], [YOS26Obligation3], [YOS26Obligation4], [YOS26Obligation5], [YOS26Obligation6], [YOS26Obligation7], [YOS26Obligation8], [YOS26Obligation9], [YOS27Obligation0], [YOS27Obligation1], [YOS27Obligation2], [YOS27Obligation3], [YOS27Obligation4], [YOS27Obligation5], [YOS27Obligation6], [YOS27Obligation7], [YOS27Obligation8], [YOS27Obligation9], [YOS28Obligation0], [YOS28Obligation1], [YOS28Obligation2], [YOS28Obligation3], [YOS28Obligation4], [YOS28Obligation5], [YOS28Obligation6], [YOS28Obligation7], [YOS28Obligation8], [YOS28Obligation9], [YOS29Obligation0], [YOS29Obligation1], [YOS29Obligation2], [YOS29Obligation3], [YOS29Obligation4], [YOS29Obligation5], [YOS29Obligation6], [YOS29Obligation7], [YOS29Obligation8], [YOS29Obligation9], [YOS30Obligation0], [YOS30Obligation1], [YOS30Obligation2], [YOS30Obligation3], [YOS30Obligation4], [YOS30Obligation5], [YOS30Obligation6], [YOS30Obligation7], [YOS30Obligation8], [YOS30Obligation9], [YOS31Obligation0], [YOS31Obligation1], [YOS31Obligation2], [YOS31Obligation3], [YOS31Obligation4], [YOS31Obligation5], [YOS31Obligation6], [YOS31Obligation7], [YOS31Obligation8], [YOS31Obligation9], [YOS32Obligation0], [YOS32Obligation1], [YOS32Obligation2], [YOS32Obligation3], [YOS32Obligation4], [YOS32Obligation5], [YOS32Obligation6], [YOS32Obligation7], [YOS32Obligation8], [YOS32Obligation9], [YOS33Obligation0], [YOS33Obligation1], [YOS33Obligation2], [YOS33Obligation3], [YOS33Obligation4], [YOS33Obligation5], [YOS33Obligation6], [YOS33Obligation7], [YOS33Obligation8], [YOS33Obligation9], [YOS34Obligation0], [YOS34Obligation1], [YOS34Obligation2], [YOS34Obligation3], [YOS34Obligation4], [YOS34Obligation5], [YOS34Obligation6], [YOS34Obligation7], [YOS34Obligation8], [YOS34Obligation9], [YOS35Obligation0], [YOS35Obligation1], [YOS35Obligation2], [YOS35Obligation3], [YOS35Obligation4], [YOS35Obligation5], [YOS35Obligation6], [YOS35Obligation7], [YOS35Obligation8], [YOS35Obligation9], [YOS36Obligation0], [YOS36Obligation1], [YOS36Obligation2], [YOS36Obligation3], [YOS36Obligation4], [YOS36Obligation5], [YOS36Obligation6], [YOS36Obligation7], [YOS36Obligation8], [YOS36Obligation9], [YOS37Obligation0], [YOS37Obligation1], [YOS37Obligation2], [YOS37Obligation3], [YOS37Obligation4], [YOS37Obligation5], [YOS37Obligation6], [YOS37Obligation7], [YOS37Obligation8], [YOS37Obligation9], [YOS38Obligation0], [YOS38Obligation1], [YOS38Obligation2], [YOS38Obligation3], [YOS38Obligation4], [YOS38Obligation5], [YOS38Obligation6], [YOS38Obligation7], [YOS38Obligation8], [YOS38Obligation9], [YOS39Obligation0], [YOS39Obligation1], [YOS39Obligation2], [YOS39Obligation3], [YOS39Obligation4], [YOS39Obligation5], [YOS39Obligation6], [YOS39Obligation7], [YOS39Obligation8], [YOS39Obligation9], [YOS40Obligation0], [YOS40Obligation1], [YOS40Obligation2], [YOS40Obligation3], [YOS40Obligation4], [YOS40Obligation5], [YOS40Obligation6], [YOS40Obligation7], [YOS40Obligation8], [YOS40Obligation9], [YOSGreaterThan40Obligation0], [YOSGreaterThan40Obligation1], [YOSGreaterThan40Obligation2], [YOSGreaterThan40Obligation3], [YOSGreaterThan40Obligation4], [YOSGreaterThan40Obligation5], [YOSGreaterThan40Obligation6], [YOSGreaterThan40Obligation7], [YOSGreaterThan40Obligation8], [YOSGreaterThan40Obligation9], [YOSUnknownObligation0], [YOSUnknownObligation1], [YOSUnknownObligation2], [YOSUnknownObligation3], [YOSUnknownObligation4], [YOSUnknownObligation5], [YOSUnknownObligation6], [YOSUnknownObligation7], [YOSUnknownObligation8], [YOSUnknownObligation9]))unpt
                                     --order by yosob desc
                                     --end processing step

                                     ) AS a
                            WHERE    PayPlan = 'RE' -- these tables only are for reserve values so filter down to just those
                                     AND GradeType = 'E' --these tables are only for enlisted values so filter down to just those
                            GROUP BY PayPlan ,
                                     [MOS] ,
                                     [GradeType] ,
                                     [GradeLevel] ,
                                     [YOS_Ob]

                        --end summarize step

                        ) AS b
             --end conversion step

             ) AS a
    GROUP BY PayPlan ,
             MOS ,
             GradeType ,
             GradeLevel ,
             Obligation;

--end final summary step