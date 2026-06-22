

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetChildBonusRecursive]
(
    @PayPlan NVARCHAR(3),
    @CategorySubGroupCode NVARCHAR(3),
    @GradeType NVARCHAR(3),
    @GradeLevel TINYINT,
    @whichone NVARCHAR(30)
)
RETURNS FLOAT
BEGIN

    DECLARE @currentValue NVARCHAR(3);
    DECLARE @currentChild NVARCHAR(3);
    DECLARE @nextChild NVARCHAR(3);
    DECLARE @FinalResult FLOAT = 0.0;
    DECLARE @childvalue FLOAT = 0.0;
    DECLARE @currentbonus FLOAT = 0.0;
    DECLARE @runningTotal FLOAT = 0.0;
    DECLARE @test FLOAT = 0.0;

    DECLARE @TEMPperc FLOAT = 0.0;
    DECLARE @totalchildren INT = 0;
    DECLARE @i INT = 1;

    SET @currentValue = @CategorySubGroupCode;

    DECLARE @TempMOS TABLE
    (
        [MOS] NVARCHAR(3),
        [childMOS] NVARCHAR(1)
    );

    INSERT INTO @TempMOS
    (
        [MOS],
        [childMOS]
    )
    SELECT MOS,
           NULL
    FROM lookup.MOS
    WHERE Parent_MOS = @currentValue;

    SET @totalchildren =
    (
        SELECT COUNT(MOS) FROM @TempMOS
    );

    WHILE (@i <= @totalchildren)
    BEGIN
        SET @currentChild =
        (
            SELECT TOP 1 MOS FROM @TempMOS WHERE childMOS IS NULL
        );

        --CostOfRecruiting
        IF @whichone = 'Recruiting'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(bonus_capped_amt / CGLA_inv) OVER (PARTITION BY PayPlan,
                                                                       CategorySubGroupCode
                                                          ORDER BY PayPlan,
                                                                   CategorySubGroupCode,
                                                                   GradeLevel ASC
                                                         ) AS mybonus
            FROM crunch.TempRecruiting_Costs
            WHERE CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;

        --CostOfOfficerAcquisition
        IF @whichone = 'OfficerAcquisition'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(bonus_mpa / CGLA_inv) OVER (PARTITION BY PayPlan,
                                                                CategorySubGroupCode
                                                   ORDER BY PayPlan,
                                                            CategorySubGroupCode,
                                                            GradeLevel ASC
                                                  ) AS CGLA_Bonus
            FROM crunch.TempOfc_Acq_by_AOC
            WHERE CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;



        --CostOfSelectiveRetentionBonus
        IF @whichone = 'RetentionBonus'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(avg_annual_pay / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                          CategorySubGroupCode
                                                             ORDER BY PayPlan,
                                                                      CategorySubGroupCode,
                                                                      GradeLevel ASC
                                                            )
AS              CGLA_Bonus
            FROM crunch.TempSRBPay
            WHERE CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;


        IF (@childvalue IS NULL)
            SET @childvalue = 0;

        SET @TEMPperc = crunch.GetParentSharePercentage(@PayPlan, @currentChild, @GradeType);

        SET @runningTotal
            = @runningTotal
              + (@TEMPperc
                 * (@childvalue
                    + crunch.GetChildBonusRecursive(@PayPlan, @currentChild, @GradeType, @GradeLevel, @whichone)
                   )
                );
        SET @i = @i + 1;
        UPDATE @TempMOS
        SET childMOS = 'Y'
        WHERE MOS = @currentChild;
    END;

    IF (@totalchildren = 0)
        RETURN 0;
    SET @FinalResult = (@runningTotal);

    RETURN @FinalResult;
END;