

-- =================================================================================================
-- Author:		
-- Create date: 
-- Description:	Maximum pay amount by GS schedule (special pay is allowed to trump this)
--  5/25/2022 with the new EX payschedule we no longer need a single value and can get that right from the pay schedule
--  per 5 USC 5304 (g)(1) the max G series pay is based on EX Level IV
-- =================================================================================================
CREATE FUNCTION [crunch].[GetMaximumGSPayLimit]
(
    @AmcosVersionId INT
)
RETURNS NUMERIC(15, 2)
AS
BEGIN
    DECLARE @Result NUMERIC(15, 2);

    SELECT @Result = Rate
    FROM PaySchedule.OpmExRaw
    WHERE AmcosVersionId = @AmcosVersionId
          AND RateType = 'Annual'
          AND [Level] = 'Level IV';

    --prior to 1994 there was no executive schedule so we just set the cap to something so high it won't factor in to the cap
    IF @Result IS NULL
       AND @AmcosVersionId < 199401
        SET @Result = 999999;

    RETURN @Result;

END;