

-- =============================================
-- Author:		Dan Hogan
-- Create date: 3/8/2020
-- Description:	Convert N and D series payschedule crosswalks into real payschedule data
--Edits:
-- 8/26/2022 - code was not correctly incorporating GFEBS overseas location pay schedule data, fixed via this update
-- =============================================
CREATE PROCEDURE [crunch].[CrunchPayScheduleDSeriesNSeries]
    @AmcosVersionId INT = -1,
    @Debug BIT = -1
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #MasterTable;
    CREATE TABLE #MasterTable
    (
        PayPlan NVARCHAR(2) NOT NULL,
        Strl NVARCHAR(50) NOT NULL,
        PayBand INT NOT NULL,
        Min_GS_GL NVARCHAR(3) NOT NULL,
        Max_GS_GL NVARCHAR(3) NOT NULL,
        Additional NUMERIC(17, 2) NULL,
        LocalityCode NVARCHAR(50) NOT NULL,
        LocalityRate NUMERIC(17, 2) NOT NULL,
        MinPay NUMERIC(17, 2) NULL,
        MaxPay NUMERIC(17, 2) NULL
    );

    INSERT INTO #MasterTable
    (
        PayPlan,
        Strl,
        PayBand,
        Min_GS_GL,
        Max_GS_GL,
        Additional,
        LocalityCode,
        LocalityRate,
        MinPay,
        MaxPay
    )
    SELECT a.PayPlan,
           a.Strl,
           a.PayBand,
           a.Min_GS_GL,
           a.Max_GS_GL,
           a.Additional,
           b.LocalityCode,
           b.LocalityRate,
           0.0 AS minpay,
           0.0 AS maxpay
    FROM
    (
        SELECT PayPlan,
               Strl,
               PayBand,
               Min_GS_GL,
               Max_GS_GL,
               Additional
        FROM PaySchedule.PaySchedule_DSeries_Xwalk
        WHERE @AmcosVersionId
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
        UNION
        SELECT PayPlan,
               '-1',
               PayBand,
               Min_GS_GL,
               Max_GS_GL,
               Additional
        FROM PaySchedule.PaySchedule_NSeries_Xwalk
        WHERE @AmcosVersionId
        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
    ) AS a
        CROSS JOIN
        (
            SELECT LocalityCode,
                   LocalityRate,
                   AmcosVersionId
            FROM PaySchedule.LocalityPay
            UNION
            --overseas pay is based on the OPM GS base schedule 
            SELECT SourceSystemCode LocalityCode,
                   0 LocalityRate,
                   @AmcosVersionId AmcosVersionId
            FROM warehouse.Location
            WHERE LocationType = 'GFEBS Country'
                  AND SourceSystemCode <> '-1'
        ) AS b
    WHERE @AmcosVersionId = b.AmcosVersionId;



    --bring in minimums which are step 1s
    UPDATE #MasterTable
    SET MinPay = b.Rate * (1 + a.LocalityRate / 100)
    FROM #MasterTable AS a
        INNER JOIN PaySchedule.PaySchedule_G_Series_raw AS b
            ON a.Min_GS_GL = CAST(b.GradeLevel AS NVARCHAR(3))
    WHERE b.Step = 1
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.PayPlan = 'GS'
          AND b.RateType = 'Annual';

    --bring in maximums which are step 10s + any additional amount
    UPDATE #MasterTable
    SET MaxPay = b.Rate * (1 + a.LocalityRate / 100) + ISNULL(a.Additional, 0)
    FROM #MasterTable AS a
        INNER JOIN PaySchedule.PaySchedule_G_Series_raw AS b
            ON a.Max_GS_GL = CAST(b.GradeLevel AS NVARCHAR(3))
    WHERE b.Step = 10
          AND b.AmcosVersionId = @AmcosVersionId
          AND b.PayPlan = 'GS'
          AND b.RateType = 'Annual';

    --bring in min ses pay
    UPDATE #MasterTable
    SET MinPay =
        (
            SELECT MinPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
        )
    WHERE Min_GS_GL = 'SES';

    --bring in max ses pay
    UPDATE #MasterTable
    SET MaxPay =
        (
            SELECT TOP (1)
                   MaxPay
            FROM PaySchedule.OpmSesRaw
            WHERE RateType = 'Annual'
                  AND AmcosVersionId = @AmcosVersionId
            ORDER BY MaxPay
        )
    WHERE Max_GS_GL = 'SES';

    IF @Debug = 1
    BEGIN
        SELECT 'entire table before insert without locationid';
        SELECT *
        FROM #MasterTable;
    END;

    IF @Debug = 0
    BEGIN

        DELETE FROM PaySchedule.PaySchedule_D_NSeries
        WHERE AmcosVersionId = @AmcosVersionId;
        INSERT INTO PaySchedule.PaySchedule_D_NSeries
        (
            PayPlan,
            Strl,
            GradeType,
            PayBand,
            MinPay,
            MaxPay,
            LocationId,
            AmcosVersionId
        )
        SELECT a.PayPlan,
               a.Strl,
               a.PayPlan,
               a.PayBand,
               a.MinPay,
               a.MaxPay,
               b.LocationId,
               @AmcosVersionId
        FROM #MasterTable AS a
            INNER JOIN warehouse.Location AS b
                ON a.LocalityCode = b.SourceSystemCode
        UNION
        --insert base pay which doesn't have a real locationid
        SELECT a.PayPlan,
               a.Strl,
               a.PayPlan,
               a.PayBand,
               a.MinPay,
               a.MaxPay,
               -1,
               @AmcosVersionId
        FROM #MasterTable AS a
        WHERE a.LocalityCode = 'BASE PAY';


    END;
END;