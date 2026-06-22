/* =============================================
-- Author:		Name
-- Create date: 
-- Description:	
   if there are no members then force some number
   when writing this the only case was RO O9 (Chief Army Reserve which its not known why that is zero when the position is filled)
   we calculate using a weighted average of those with and without dependents against the corresponding rate for each
-- ============================================= */
CREATE FUNCTION [crunch].[GetReserveComponentBAH]
(
    @RateWithDependents NUMERIC(7, 2),
    @RateWithoutDependents NUMERIC(7, 2),
    @TotalMembers NUMERIC(19, 0),
    @MembersWithDependents NUMERIC(19, 0),
    @MembersWithoutDependents NUMERIC(19, 0)
)
RETURNS NUMERIC(16, 2)
AS
BEGIN
    DECLARE @Result NUMERIC(16, 2);

    IF @TotalMembers = 0
       OR @TotalMembers IS NULL
    BEGIN
        SET @Result = @RateWithDependents;
    END;
    ELSE
    BEGIN
        SET @Result
            = (@RateWithDependents * (@MembersWithDependents / @TotalMembers))
              + (@RateWithoutDependents * (@MembersWithoutDependents / @TotalMembers));
    END;

    RETURN @Result;

END;