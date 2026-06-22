

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetPMReportInflationRateHeader]
(
    @ProjectId INTEGER,
    @AmcosVersionId INTEGER
)
RETURNS @Table_Var TABLE
(
    [Year] INTEGER PRIMARY KEY,
    [Army CivPay] NUMERIC(6, 4) NOT NULL,
    [Federal OM] NUMERIC(6, 4) NOT NULL,
    [MPA] NUMERIC(6, 4) NOT NULL,
    [MPA Non-Pay] NUMERIC(6, 4) NOT NULL,
    [NGPA] NUMERIC(6, 4) NOT NULL,
    [OMA] NUMERIC(6, 4) NOT NULL,
    [OMA_1] NUMERIC(6, 4) NOT NULL,
    [OMAR] NUMERIC(6, 4) NOT NULL,
    [OMAR_1] NUMERIC(6, 4) NOT NULL,
    [OMDW] NUMERIC(6, 4) NOT NULL,
    [OMNG] NUMERIC(6, 4) NOT NULL,
    [OMNG_1] NUMERIC(6, 4) NOT NULL,
    [RPA] NUMERIC(6, 4) NOT NULL
)
AS
BEGIN
    DECLARE @ConversionType NVARCHAR(25) = N'ThenToThen';

    INSERT INTO @Table_Var
    SELECT DISTINCT
           PMCategorySkillInventory.[Year],
           Inflation.[Army CivPay],
           Inflation.[Federal OM],
           Inflation.[MPA],
           Inflation.[MPA Non-Pay],
           Inflation.[NGPA],
           Inflation.[OMA],
           Inflation.[OMA_1],
           Inflation.[OMAR],
           Inflation.[OMAR_1],
           Inflation.[OMDW],
           Inflation.[OMNG],
           Inflation.[OMNG_1],
           Inflation.[RPA]
    FROM webuser.PMReport PMReport
        INNER JOIN web.PMCategorySkillInventory PMCategorySkillInventory
            ON PMCategorySkillInventory.CategoryId = PMReport.CategoryId
               AND PMCategorySkillInventory.PayPlan = PMReport.PayPlan
        CROSS APPLY web.GetInflationRateHeader(@ConversionType, (PMCategorySkillInventory.Year), @AmcosVersionId) Inflation
    WHERE PMCategorySkillInventory.ProjectId = @ProjectId;

    RETURN;

END;