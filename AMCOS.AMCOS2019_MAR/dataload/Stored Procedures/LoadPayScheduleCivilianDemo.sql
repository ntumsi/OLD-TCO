
CREATE PROCEDURE [dataload].[LoadPayScheduleCivilianDemo]
AS
BEGIN
    /* The following are the business rules which guide the Acq and Lab Demo pay plans and insert values
   into their pay schedule based on the GS and SES pay schedule.
   The GS pay schedule MUST BE UPDATED BEFORE THIS IS RUN */

    DECLARE @PayPlan AS NVARCHAR(3);
    DECLARE @PayBand AS TINYINT;
    DECLARE @Step AS INT;
    --NH
    --Bay Band 1
    SET @PayPlan = N'NH';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 11
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 12
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 13
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 4
    SET @PayBand = 4;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 14
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;


    --NJ
    --Bay Band 1
    SET @PayPlan = N'NJ';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 8
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 9
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 11
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 4
    SET @PayBand = 4;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 12
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 13
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;



    --NK
    --Bay Band 1
    SET @PayPlan = N'NK';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 7
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 8
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 10
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;





    --DB
    --Bay Band 1
    SET @PayPlan = N'DB';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 12
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 13
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 14
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 4
    SET @PayBand = 4;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 5
    SET @PayBand = 5;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate * 1.2
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_SES
    WHERE GradeLevel = 3
    ORDER BY DateEffective DESC;



    --DE
    --Bay Band 1
    SET @PayPlan = N'DE';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 8
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 9
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 11
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;


    --Bay Band 4
    SET @PayBand = 4;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 12
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 13
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;




    --DJ
    --Bay Band 1
    SET @PayPlan = N'DJ';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 10
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 11
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 12
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 4
    SET @PayBand = 4;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 13
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 14
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;


    --Bay Band 5
    SET @PayBand = 5;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 15
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;


    --DK
    --Bay Band 1
    SET @PayPlan = N'DK';
    SET @PayBand = 1;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 1
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 4
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 2
    SET @PayBand = 2;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 5
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 8
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    --Bay Band 3
    SET @PayBand = 3;
    SET @Step = 0;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 9
          AND Step = 1
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

    SET @Step = 1;
    INSERT INTO load_payschedule.PaySchedule_CivilianDemonstration
    (
        PayPlan,
        GradeType,
        PayBand,
        Step,
        DateEffective,
        RateType,
        Rate
    )
    SELECT TOP (1)
           @PayPlan,
           @PayPlan,
           @PayBand,
           @Step,
           DateEffective,
           RateType,
           Rate
    FROM load_payschedule.PaySchedule_GS
    WHERE GradeLevel = 10
          AND Step = 10
          AND RateType = 'Annual'
    ORDER BY DateEffective DESC;

END;