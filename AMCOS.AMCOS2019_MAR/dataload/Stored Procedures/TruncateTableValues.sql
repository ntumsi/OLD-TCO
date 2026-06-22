-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateTableValues]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE dataload.AE_MilCompAllowances;
    TRUNCATE TABLE dataload.AE_OtherBenefits;
    TRUNCATE TABLE dataload.AE_PCS;
    TRUNCATE TABLE dataload.AE_SpecialPays;
    TRUNCATE TABLE dataload.AE_SpecialPaysElig;
    TRUNCATE TABLE dataload.AO_MilCompAllowances;
    TRUNCATE TABLE dataload.AO_OtherBenefits;
    TRUNCATE TABLE dataload.AO_PCS;
    TRUNCATE TABLE dataload.AO_ProjEndstrength;
    TRUNCATE TABLE dataload.AO_SpecialPaysBudget;
    TRUNCATE TABLE dataload.AO_SpecialPaysElig;
    TRUNCATE TABLE dataload.NE_MilCompAllowances;
    TRUNCATE TABLE dataload.NO_MilCompAllowances;
    TRUNCATE TABLE dataload.RE_MilCompAllowances;
    TRUNCATE TABLE dataload.RO_MilCompAllowances;
    TRUNCATE TABLE dataload.RO_ProjectedInventory;
    TRUNCATE TABLE dataload.MilitaryAccessions;
    TRUNCATE TABLE dataload.SepParms;
END;