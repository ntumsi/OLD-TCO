
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateProjectManager]
AS
BEGIN

    SET NOCOUNT ON;

    DELETE webuser.PMCategorySkillInventory;
    DELETE webuser.PMCategorySkill;
    DELETE webuser.PMReport;
    DELETE webuser.PMCategory;
    DELETE webuser.PMProject;

END;