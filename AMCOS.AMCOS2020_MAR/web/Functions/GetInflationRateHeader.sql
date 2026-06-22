
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetInflationRateHeader]
(
    @ConversionType NVARCHAR(25),
    @Year NVARCHAR(4),
    @AmcosVersionId INT
)
RETURNS @Table_Var TABLE
(
    Year INTEGER NOT NULL,
    Appropriation NVARCHAR(25) NOT NULL,
    [Army CivPay] NUMERIC(18, 15) NULL,
    [Federal OM] NUMERIC(18, 15) NULL,
    [MPA] NUMERIC(18, 15) NULL,
    [MPA Non-Pay] NUMERIC(18, 15) NULL,
    [NGPA] NUMERIC(18, 15) NULL,
    [OMA] NUMERIC(18, 15) NULL,
    [OMA_1] NUMERIC(18, 15) NULL,
    [OMAR] NUMERIC(18, 15) NULL,
    [OMAR_1] NUMERIC(18, 15) NULL,
    [OMDW] NUMERIC(18, 15) NULL,
    [OMNG] NUMERIC(18, 15) NULL,
    [OMNG_1] NUMERIC(18, 15) NULL,
    [RPA] NUMERIC(18, 15) NULL
)
AS
BEGIN
    INSERT INTO @Table_Var
    SELECT [Year],
           'Inflation Rate' AS Appropriation,
           [Army CivPay],
           [Federal OM],
           [MPA],
           [MPA Non-Pay],
           [NGPA],
           [OMA],
           [OMA_1],
           [OMAR],
           [OMAR_1],
           [OMDW],
           [OMNG],
           [OMNG_1],
           [RPA]
    FROM
    (
        SELECT Year,
               Appropriation,
               Amount
        FROM lookup.JicInflationRates
        WHERE ConversionType = @ConversionType
              AND Year = @Year
              AND AmcosVersionId = @AmcosVersionId
    ) AS SourceTable
    PIVOT
    (
        SUM(Amount)
        FOR Appropriation IN ([Army CivPay], [Federal OM], [MPA], [MPA Non-Pay], [NGPA], [OMA], [OMA_1], [OMAR],
                              [OMAR_1], [OMDW], [OMNG], [OMNG_1], [RPA]
                             )
    ) AS PivotTable;

    RETURN;

END;