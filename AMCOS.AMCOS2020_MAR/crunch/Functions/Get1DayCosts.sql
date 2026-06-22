-- =============================================
-- Author:		Dan Hogan
-- Create date: 11/2/2019
-- Description:	This returns exactly what is in the 1 day crunch table * number of days with the exception of
--		social security which is capped on the fly should a user enter enough days to hit the cap
-- =============================================
CREATE FUNCTION [crunch].[Get1DayCosts]
(
    @AmcosVersionId INT = -1,
    @ActiveDutyDays INT = -1
)
RETURNS @ReserveComponentCosts TABLE
(
    [PayPlan] [NVARCHAR](3) NOT NULL,
    [CategoryGroupCode] [NCHAR](2) NOT NULL,
    [CategorySubgroupCode] [NVARCHAR](4) NOT NULL,
    [CostElementId] [INT] NOT NULL,
    [GradeType] [NVARCHAR](3) NOT NULL,
    [GradeLevel] [TINYINT] NOT NULL,
    [WeaponSystemId] [INT] NOT NULL,
    [Amount] [NUMERIC](20, 2) NOT NULL,
    [CrunchTime] [SMALLDATETIME] NULL,
    [AmcosVersionId] [INT] NOT NULL
)
AS
BEGIN
    INSERT INTO @ReserveComponentCosts
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        CostElementId,
        GradeType,
        GradeLevel,
        WeaponSystemId,
        Amount,
        CrunchTime,
        AmcosVersionId
    )
    SELECT PayPlan,
           CMF,
           MOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NE
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT a.CostElementId
            FROM lookup.CostSummaryElement AS a
                INNER JOIN lookup.CostSummary AS b
                    ON a.SummaryId = b.SummaryId
                       AND b.Name = 'Default'
                       AND b.PayPlan IN ( 'NE' )
                       AND @AmcosVersionId
                       BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        )
    UNION
    SELECT PayPlan,
           CMF,
           MOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RE
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT a.CostElementId
            FROM lookup.CostSummaryElement AS a
                INNER JOIN lookup.CostSummary AS b
                    ON a.SummaryId = b.SummaryId
                       AND b.Name = 'Default'
                       AND b.PayPlan IN ( 'RE' )
                       AND @AmcosVersionId
                       BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        )
    UNION
    SELECT PayPlan,
           CMF,
           AOC,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NO
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT a.CostElementId
            FROM lookup.CostSummaryElement AS a
                INNER JOIN lookup.CostSummary AS b
                    ON a.SummaryId = b.SummaryId
                       AND b.Name = 'Default'
                       AND b.PayPlan IN ( 'NO' )
                       AND @AmcosVersionId
                       BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        )
    UNION
    SELECT PayPlan,
           CMF,
           AOC,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RO
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT CostElementId
            FROM lookup.CostSummaryElement AS a
                INNER JOIN lookup.CostSummary AS b
                    ON a.SummaryId = b.SummaryId
                       AND b.Name = 'Default'
                       AND PayPlan IN ( 'RO' )
                       AND @AmcosVersionId
                       BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        )
    UNION
    SELECT PayPlan,
           Branch,
           WOMOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_NWO
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT CostElementId
            FROM lookup.CostSummaryElement AS a
                INNER JOIN lookup.CostSummary AS b
                    ON a.SummaryId = b.SummaryId
                       AND b.Name = 'Default'
                       AND PayPlan IN ( 'NWO' )
                       AND @AmcosVersionId
                       BETWEEN a.AmcosVersionIdStart AND a.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN b.AmcosVersionIdStart AND b.AmcosVersionIdEnd
        )
    UNION
    SELECT PayPlan,
           Branch,
           WOMOS,
           CostElementId,
           GradeType,
           GradeLevel,
           WeaponSystemId,
           Amount,
           CrunchTime,
           AmcosVersionId
    FROM crunch.Costs_RWO
    WHERE AmcosVersionId = @AmcosVersionId
          AND
        /* only want default elements */
        CostElementId IN
        (
            SELECT CostSummaryElement.CostElementId
            FROM lookup.CostSummaryElement CostSummaryElement
                INNER JOIN lookup.CostSummary CostSummary
                    ON CostSummaryElement.SummaryId = CostSummary.SummaryId
                       AND CostSummary.Name = 'Default'
                       AND CostSummary.PayPlan IN ( 'RWO' )
                       AND @AmcosVersionId
                       BETWEEN CostSummaryElement.AmcosVersionIdStart AND CostSummaryElement.AmcosVersionIdEnd
                       AND @AmcosVersionId
                       BETWEEN CostSummary.AmcosVersionIdStart AND CostSummary.AmcosVersionIdEnd
        );

    /* add to the base costs, the number of days of cost the user asked for */
    UPDATE @ReserveComponentCosts
    SET Amount = a.Amount + b.Amount * @ActiveDutyDays
    FROM @ReserveComponentCosts AS a
        INNER JOIN crunch.Costs_1ActiveDay AS b
            ON a.CostElementId = b.CostElementId
               AND a.AmcosVersionId = b.AmcosVersionId
               AND a.PayPlan = b.PayPlan
               AND a.CategoryGroupCode = b.CategoryGroupCode
               AND a.CategorySubgroupCode = b.CategorySubgroupCode
               AND a.GradeLevel = b.GradeLevel
               AND a.WeaponSystemId = b.WeaponSystemId;

    /* lastly, we must temper the social security amount by the max allowed */
    DECLARE @Max_Wage_SSW NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);

    UPDATE @ReserveComponentCosts
    SET Amount = CASE
                     WHEN Amount > @Max_Wage_SSW THEN
                         @Max_Wage_SSW
                     ELSE
                         Amount
                 END
    WHERE CostElementId IN ( 290, 360, 414, 454, 524, 578 );

    RETURN;
END;