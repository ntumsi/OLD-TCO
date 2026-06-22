

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[GetChildTrainingWeaponsRecursive]
(
    @PayPlan NVARCHAR(3),
    @CategorySubGroupCode NVARCHAR(3),
    @GradeType NVARCHAR(3),
    @CourseType NVARCHAR(10),
    @WeaponSystemName NVARCHAR(50),
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


        SET @childvalue =
        (
            SELECT TOP (1)
                   CASE
                       WHEN @whichone = 'TrainingMPA' THEN
                           SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                     CategorySubGroupCode,
                                                                                     coursetype,
                                                                                     WeaponSystemName
                                                                        ORDER BY PayPlan,
                                                                                 CategorySubGroupCode,
                                                                                 coursetype,
                                                                                 WeaponSystemName,
                                                                                 GradeLevel ASC
                                                                       )
                       WHEN @whichone = 'TrainingOMA' THEN
                           SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                     CategorySubGroupCode,
                                                                                     coursetype,
                                                                                     WeaponSystemName
                                                                        ORDER BY PayPlan,
                                                                                 CategorySubGroupCode,
                                                                                 coursetype,
                                                                                 WeaponSystemName,
                                                                                 GradeLevel ASC
                                                                       )
                       WHEN @whichone = 'TrainingOther' THEN
                           SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                       CategorySubGroupCode,
                                                                                       coursetype,
                                                                                       WeaponSystemName
                                                                          ORDER BY PayPlan,
                                                                                   CategorySubGroupCode,
                                                                                   coursetype,
                                                                                   WeaponSystemName,
                                                                                   GradeLevel ASC
                                                                         )
                       ELSE
                           0
                   END
AS              thechildvalue
            FROM crunch.TempTraining_Costs
            WHERE coursetype = 'W'
                  --AND GradeType = 'E'
                  AND CategorySubGroupCode = @currentChild
                  AND PayPlan = @PayPlan
                  AND coursetype = @CourseType
                  AND WeaponSystemName = @WeaponSystemName
            ORDER BY GradeLevel DESC
        );


        IF (@childvalue IS NULL)
            SET @childvalue = 0;

        SET @TEMPperc = crunch.GetParentSharePercentage(@PayPlan, @currentChild, @GradeType);

        SET @runningTotal
            = @runningTotal
              + (@TEMPperc
                 * (@childvalue
                    + crunch.GetChildTrainingWeaponsRecursive(
                                                                 @PayPlan,
                                                                 @currentChild,
                                                                 @GradeType,
                                                                 @CourseType,
                                                                 @WeaponSystemName,
                                                                 @GradeLevel,
                                                                 @whichone
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