
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


        SET @childvalue =
        (
            SELECT TOP (1)
                   CASE
                       WHEN @whichone = 'TrainingMPA' THEN
                           SUM(MPA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                     CategorySubgroupCode,
                                                                                     CourseType,
                                                                                     WeaponSystemName
                                                                        ORDER BY PayPlan,
                                                                                 CategorySubgroupCode,
                                                                                 CourseType,
                                                                                 WeaponSystemName,
                                                                                 GradeLevel ASC
                                                                       )
                       WHEN @whichone = 'TrainingOMA' THEN
                           SUM(OMA_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                     CategorySubgroupCode,
                                                                                     CourseType,
                                                                                     WeaponSystemName
                                                                        ORDER BY PayPlan,
                                                                                 CategorySubgroupCode,
                                                                                 CourseType,
                                                                                 WeaponSystemName,
                                                                                 GradeLevel ASC
                                                                       )
                       WHEN @whichone = 'TrainingOther' THEN
                           SUM(Other_MOS / NULLIF(CGLA_MOS_inv, 0)) OVER (PARTITION BY PayPlan,
                                                                                       CategorySubgroupCode,
                                                                                       CourseType,
                                                                                       WeaponSystemName
                                                                          ORDER BY PayPlan,
                                                                                   CategorySubgroupCode,
                                                                                   CourseType,
                                                                                   WeaponSystemName,
                                                                                   GradeLevel ASC
                                                                         )
                       ELSE
                           0
                   END
AS              thechildvalue
            FROM crunch_temp.TrainingCosts
            WHERE CourseType = 'W'
                  --AND GradeType = 'E'
                  AND CategorySubgroupCode = @currentChild
                  AND PayPlan = @PayPlan
                  AND CourseType = @CourseType
                  AND WeaponSystemName = @WeaponSystemName
            ORDER BY GradeLevel DESC
        );


        IF (@childvalue IS NULL)
            SET @childvalue = 0;

        SET @TEMPperc = crunch.GetChildInventoryPercentage(@PayPlan, @currentChild, @AmcosVersionId);

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