
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[CostsCCEInflated]
(
    @CategorySubgroupCode NVARCHAR(10),
    @Area NVARCHAR(10),
    @OverheadPercent MONEY,
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4)
)
RETURNS @Costs TABLE
(
    appnGroup NVARCHAR(50) NULL,
    [Cost Element Name] NVARCHAR(250) NULL,
    [Description] NVARCHAR(MAX) NULL,
    A_PCT10 NUMERIC(18, 0) NULL,
    A_PCT25 NUMERIC(18, 0) NULL,
    A_MEDIAN NUMERIC(18, 0) NULL,
    A_PCT75 NUMERIC(18, 0) NULL,
    A_PCT90 NUMERIC(18, 0) NULL
)
AS
BEGIN

    DECLARE @BenefitRatio NUMERIC(18, 4);
    DECLARE @payLimit MONEY;
    DECLARE @payLimitBenefit MONEY;
    DECLARE @payLimitOverhead MONEY;
    DECLARE @payLimitTotal MONEY;


    SELECT @BenefitRatio = paramValue
    FROM dataload.SingleValues
    WHERE PayPlan = 'CCE'
          AND paramName = 'Benefits_All';

    SET @payLimit = 208000.00;
    SELECT @payLimitBenefit = CONVERT(MONEY, (@payLimit * @BenefitRatio), 1);
    SELECT @payLimitOverhead = CONVERT(MONEY, (@payLimit * @OverheadPercent / 100), 1);
    SELECT @payLimitTotal = CONVERT(MONEY, (@payLimit * (1 + @BenefitRatio + @OverheadPercent / 100)), 1);

    INSERT INTO @Costs
    (
        appnGroup,
        [Cost Element Name],
        [Description],
        A_PCT10,
        A_PCT25,
        A_MEDIAN,
        A_PCT75,
        A_PCT90
    )
    SELECT 'CCE' AS appnGroup,
           'zzz1Avg Cost of Salary' AS [Cost Element Name],
           'Annual salary received in the private sector.' AS [Description],
           (CASE
                WHEN A_PCT10 = 9999999 THEN
                    @payLimit
                ELSE
                    CONVERT(MONEY, A_PCT10, 1)
            END
           ) AS A_PCT10,
           (CASE
                WHEN A_PCT25 = 9999999 THEN
                    @payLimit
                ELSE
                    CONVERT(MONEY, A_PCT25, 1)
            END
           ) AS A_PCT25,
           (CASE
                WHEN A_MEDIAN = 9999999 THEN
                    @payLimit
                ELSE
                    CONVERT(MONEY, A_MEDIAN, 1)
            END
           ) AS A_MEDIAN,
           (CASE
                WHEN A_PCT75 = 9999999 THEN
                    @payLimit
                ELSE
                    CONVERT(MONEY, A_PCT75, 1)
            END
           ) AS A_PCT75,
           (CASE
                WHEN A_PCT90 = 9999999 THEN
                    @payLimit
                ELSE
                    CONVERT(MONEY, A_PCT90, 1)
            END
           ) AS A_PCT90
    FROM dataload.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @CategorySubgroupCode
          AND AreaCode = @Area
    UNION
    SELECT 'CCE' AS appnGroup,
           'zzz2Avg Cost of Benefits' AS [Cost Element Name],
           'Employer Costs for Employee Compensation (ECEC), a product of the National Compensation Survey, measures employer costs for wages, salaries, and employee benefits for nonfarm private and state and local government workers' AS [Description],
           CASE
               WHEN A_PCT10 = 9999999 THEN
                   @payLimitBenefit
               ELSE
                   CONVERT(MONEY, A_PCT10 * @BenefitRatio, 1)
           END,
           CASE
               WHEN A_PCT25 = 9999999 THEN
                   @payLimitBenefit
               ELSE
                   CONVERT(MONEY, A_PCT25 * @BenefitRatio, 1)
           END,
           CASE
               WHEN A_MEDIAN = 9999999 THEN
                   @payLimitBenefit
               ELSE
                   CONVERT(MONEY, A_MEDIAN * @BenefitRatio, 1)
           END,
           CASE
               WHEN A_PCT75 = 9999999 THEN
                   @payLimitBenefit
               ELSE
                   CONVERT(MONEY, A_PCT75 * @BenefitRatio, 1)
           END,
           CASE
               WHEN A_PCT90 = 9999999 THEN
                   @payLimitBenefit
               ELSE
                   CONVERT(MONEY, A_PCT90 * @BenefitRatio, 1)
           END
    FROM dataload.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @CategorySubgroupCode
          AND AreaCode = @Area
    UNION
    SELECT 'CCE' AS appnGroup,
           'zzz3Overhead' AS [Cost Element Name],
           'An ongoing business expenses not including or related to direct labor, direct materials or third-party expenses that are billed directly to customers. Overhead must be paid for on an ongoing basis, regardless of whether a company is doing a high or low volume of business. It is important not just for budgeting purposes, but for determining how much a company must charge for its products or services to make a profit.',
           CASE
               WHEN A_PCT10 = 9999999 THEN
                   @payLimitOverhead
               ELSE
                   CONVERT(MONEY, A_PCT10 * @OverheadPercent / 100, 1)
           END,
           CASE
               WHEN A_PCT25 = 9999999 THEN
                   @payLimitOverhead
               ELSE
                   CONVERT(MONEY, A_PCT25 * @OverheadPercent / 100, 1)
           END,
           CASE
               WHEN A_MEDIAN = 9999999 THEN
                   @payLimitOverhead
               ELSE
                   CONVERT(MONEY, A_MEDIAN * @OverheadPercent / 100, 1)
           END,
           CASE
               WHEN A_PCT75 = 9999999 THEN
                   @payLimitOverhead
               ELSE
                   CONVERT(MONEY, A_PCT75 * @OverheadPercent / 100, 1)
           END,
           CASE
               WHEN A_PCT90 = 9999999 THEN
                   @payLimitOverhead
               ELSE
                   CONVERT(MONEY, A_PCT90 * @OverheadPercent / 100, 1)
           END
    FROM dataload.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @CategorySubgroupCode
          AND AreaCode = @Area
    UNION
    SELECT 'CCE' AS appnGroup,
           'zzz3Total' AS [Cost Element Name],
           'Total cost' AS [Description],
           CASE
               WHEN A_PCT10 = 9999999 THEN
                   @payLimitTotal
               ELSE
                   CONVERT(MONEY, A_PCT10 * (1 + @BenefitRatio + @OverheadPercent / 100), 1)
           END,
           CASE
               WHEN A_PCT25 = 9999999 THEN
                   @payLimitTotal
               ELSE
                   CONVERT(MONEY, A_PCT25 * (1 + @BenefitRatio + @OverheadPercent / 100), 1)
           END,
           CASE
               WHEN A_MEDIAN = 9999999 THEN
                   @payLimitTotal
               ELSE
                   CONVERT(MONEY, A_MEDIAN * (1 + @BenefitRatio + @OverheadPercent / 100), 1)
           END,
           CASE
               WHEN A_PCT75 = 9999999 THEN
                   @payLimitTotal
               ELSE
                   CONVERT(MONEY, A_PCT75 * (1 + @BenefitRatio + @OverheadPercent / 100), 1)
           END,
           CASE
               WHEN A_PCT90 = 9999999 THEN
                   @payLimitTotal
               ELSE
                   CONVERT(MONEY, A_PCT90 * (1 + @BenefitRatio + @OverheadPercent / 100), 1)
           END
    FROM dataload.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @CategorySubgroupCode
          AND AreaCode = @Area
    ORDER BY [Cost Element Name];

    UPDATE @Costs
    SET A_PCT10 = a.A_PCT10 * i.Amount,
        A_PCT25 = a.A_PCT25 * i.Amount,
        A_MEDIAN = a.A_MEDIAN * i.Amount,
        A_PCT75 = a.A_PCT75 * i.Amount,
        A_PCT90 = a.A_PCT90 * i.Amount
    FROM @Costs a
        INNER JOIN lookup.JicInflationRates i
            ON @InflationConversion = i.ConversionType
               AND @InflationYear = i.Year
               AND 'OMA' = i.Appropriation;

    RETURN;
END;