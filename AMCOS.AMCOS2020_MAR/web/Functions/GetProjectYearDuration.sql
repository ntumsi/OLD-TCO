-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetProjectYearDuration] 
(
	@CategoryId int
)
RETURNS int
AS
BEGIN
	DECLARE @Result int

	SELECT @Result = PMProject.YearDuration
    FROM webuser.PMCategory PMCategory
        INNER JOIN webuser.PMProject PMProject
            ON PMProject.ProjectId = PMCategory.ProjectId
    WHERE PMCategory.CategoryId = @CategoryId;

	RETURN @Result
END