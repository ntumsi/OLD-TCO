
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
    @whichone NVARCHAR(30),
    @AmcosVersionId INT = -1
)
RETURNS NUMERIC(16, 2)
BEGIN

    DECLARE @currentValue NVARCHAR(3);
    DECLARE @currentChild NVARCHAR(3);
    DECLARE @FinalResult NUMERIC(16, 2) = 0.0;
    DECLARE @childvalue NUMERIC(16, 2) = 0.0;
    DECLARE @runningTotal NUMERIC(16, 2) = 0.0;
    DECLARE @TEMPperc NUMERIC(16, 2) = 0.0;
    DECLARE @totalchildren INT = 0;
    DECLARE @i INT = 1;

    SET @currentValue = @CategorySubGroupCode;

    DECLARE @TempMOS TABLE
    (
        [MOS] NVARCHAR(3) NOT NULL,
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
    WHERE Parent_MOS = @currentValue
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );

    SET @totalchildren =
    (
        SELECT COUNT(MOS)FROM @TempMOS
    );

    WHILE (@i <= @totalchildren)
    BEGIN
        SET @currentChild =
        (
            SELECT TOP (1) MOS FROM @TempMOS WHERE childMOS IS NULL ORDER BY MOS
        );

        --CostOfRecruiting
        IF @whichone = 'Recruiting'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(bonus_capped_amt / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                            CategorySubGroupCode
                                                               ORDER BY PayPlan,
                                                                        CategorySubGroupCode,
                                                                        GradeLevel ASC
                                                              ) AS mybonus
            FROM crunch_temp.CostOfRecruiting
            WHERE CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;

        --CostOfOfficerAcquisition
        IF @whichone = 'OfficerAcquisition'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(bonus_mpa / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                     CategorySubGroupCode
                                                        ORDER BY PayPlan,
                                                                 CategorySubGroupCode,
                                                                 GradeLevel ASC
                                                       ) AS CGLA_Bonus
            FROM crunch_temp.CostOfOfficerAcquisitionByAoc
            WHERE CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;



        --CostOfSelectiveRetentionBonus
        IF @whichone = 'RetentionBonus'
            SET @childvalue =
        (
            SELECT TOP (1)
                   SUM(AverageAnnualPay / CGLAInventory) OVER (PARTITION BY PayPlan,
                                                                            CategorySubgroupCode
                                                               ORDER BY PayPlan,
                                                                        CategorySubgroupCode,
                                                                        GradeLevel ASC
                                                              )
AS              CGLA_Bonus
            FROM crunch_temp.CostOfSelectiveRetentionBonus
            WHERE CategorySubgroupCode = @currentChild
                  AND PayPlan = @PayPlan
            ORDER BY GradeLevel DESC
        )   ;


        IF (@childvalue IS NULL)
            SET @childvalue = 0;

        SET @TEMPperc = crunch.GetChildInventoryPercentage(@PayPlan, @currentChild, @AmcosVersionId);

        SET @runningTotal
            = @runningTotal
              + (@TEMPperc
                 * (@childvalue
                    + crunch.GetChildBonusRecursive(
                                                       @PayPlan,
                                                       @currentChild,
                                                       @GradeType,
                                                       @GradeLevel,
                                                       @whichone,
                                                       @AmcosVersionId
                                                   )
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