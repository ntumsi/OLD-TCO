
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[CostsCCEInflated]
(
    @StandardOccupationCode NVARCHAR(10),
    @LocationId INT,
    @OverheadPercent MONEY,
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4),
    @AmcosVersionId INTEGER
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
    DECLARE @MaxPayFootnote MONEY = crunch.GetSingleValue('CCE', 'MaxPayFootnote', @AmcosVersionId);
    DECLARE @payLimitBenefit MONEY;
    DECLARE @payLimitOverhead MONEY;
    DECLARE @payLimitTotal MONEY;

    DECLARE @MetropolitanStatisticalAreaCode NVARCHAR(7);
    SELECT @MetropolitanStatisticalAreaCode = SourceSystemCode
    FROM warehouse.Location
    WHERE LocationId = @LocationId;

    SELECT @BenefitRatio = crunch.GetSingleValue('CCE', 'Benefits_All', @AmcosVersionId);

    SELECT @payLimitBenefit = CONVERT(MONEY, (@MaxPayFootnote * @BenefitRatio), 1);
    SELECT @payLimitOverhead = CONVERT(MONEY, (@MaxPayFootnote * @OverheadPercent / 100), 1);
    SELECT @payLimitTotal = CONVERT(MONEY, (@MaxPayFootnote * (1 + @BenefitRatio + @OverheadPercent / 100)), 1);

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
                    @MaxPayFootnote
                ELSE
                    CONVERT(MONEY, A_PCT10, 1)
            END
           ) AS A_PCT10,
           (CASE
                WHEN A_PCT25 = 9999999 THEN
                    @MaxPayFootnote
                ELSE
                    CONVERT(MONEY, A_PCT25, 1)
            END
           ) AS A_PCT25,
           (CASE
                WHEN A_MEDIAN = 9999999 THEN
                    @MaxPayFootnote
                ELSE
                    CONVERT(MONEY, A_MEDIAN, 1)
            END
           ) AS A_MEDIAN,
           (CASE
                WHEN A_PCT75 = 9999999 THEN
                    @MaxPayFootnote
                ELSE
                    CONVERT(MONEY, A_PCT75, 1)
            END
           ) AS A_PCT75,
           (CASE
                WHEN A_PCT90 = 9999999 THEN
                    @MaxPayFootnote
                ELSE
                    CONVERT(MONEY, A_PCT90, 1)
            END
           ) AS A_PCT90
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @StandardOccupationCode
          AND MSACode = @MetropolitanStatisticalAreaCode
          AND AmcosVersionId = @AmcosVersionId
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
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @StandardOccupationCode
          AND MSACode = @MetropolitanStatisticalAreaCode
          AND AmcosVersionId = @AmcosVersionId
    UNION
    SELECT 'CCE' AS appnGroup,
           'zzz3Overhead' AS [Cost Element Name],
           'An ongoing business expenses not including or related to direct labor, direct materials or third-party expenses that are billed directly to customers. Overhead must be paid for on an ongoing basis, regardless of whether a company is doing a high or low volume of business. It is important not just for budgeting purposes, but for determining how much a company must charge for its products or services to make a profit.' AS [Description],
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
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @StandardOccupationCode
          AND MSACode = @MetropolitanStatisticalAreaCode
          AND AmcosVersionId = @AmcosVersionId
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
    FROM BLS_OES.OccupationalEmploymentStatisticsMetro
    WHERE SOC = @StandardOccupationCode
          AND MSACode = @MetropolitanStatisticalAreaCode
          AND AmcosVersionId = @AmcosVersionId
    ORDER BY [Cost Element Name];

    UPDATE @Costs
    SET A_PCT10 = Costs.A_PCT10 * InflationRates.Amount,
        A_PCT25 = Costs.A_PCT25 * InflationRates.Amount,
        A_MEDIAN = Costs.A_MEDIAN * InflationRates.Amount,
        A_PCT75 = Costs.A_PCT75 * InflationRates.Amount,
        A_PCT90 = Costs.A_PCT90 * InflationRates.Amount
    FROM @Costs Costs
        INNER JOIN lookup.JicInflationRates InflationRates
            ON @InflationConversion = InflationRates.ConversionType
               AND @InflationYear = InflationRates.Year
               AND 'OMA' = InflationRates.Appropriation
        INNER JOIN
        (
            SELECT ConversionType,
                   Year,
                   Appropriation,
                   MAX(AmcosVersionId) AS AmcosVersionIdEndMax
            FROM lookup.JicInflationRates
            GROUP BY ConversionType,
                     Year,
                     Appropriation
        ) AS MaxVersion
            ON InflationRates.ConversionType = MaxVersion.ConversionType
               AND InflationRates.Year = MaxVersion.Year
               AND InflationRates.Appropriation = MaxVersion.Appropriation
               AND InflationRates.AmcosVersionId = MaxVersion.AmcosVersionIdEndMax;

    RETURN;
END;