-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetAdjustedAvgAnnualizedCostOfFica]
(
    @CostElementId INT,
    @Amount NUMERIC(26, 6),
    @AmcosVersionId INT = 202001
)
RETURNS NUMERIC(26, 6)
AS
BEGIN
    DECLARE @Result NUMERIC(26, 6);


    /* Limit Avg Annualized Cost of FICA amount by the maximum allowed */
    DECLARE @MaximumWageSocialSecurity NUMERIC(20, 2) = crunch.GetSingleValue('AA', 'Max_Wage_SSW', @AmcosVersionId);

    IF @CostElementId IN ( 290, 360, 414, 454, 524, 578 )
        SELECT @Result = CASE
                             WHEN @Amount > @MaximumWageSocialSecurity THEN
                                 @MaximumWageSocialSecurity
                             ELSE
                                 @Amount
                         END;
    ELSE
        SELECT @Result = @Amount;

    RETURN @Result;

END;