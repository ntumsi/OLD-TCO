
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PMSkillIdForProject] ( @ProjectID INT )
RETURNS TABLE
AS
RETURN
    ( SELECT    ucs.SkillId ,
                ucs.CategoryGroupCode
      FROM      webuser.PMReport ur
                INNER JOIN webuser.PMCategorySkill ucs ON ucs.UserId = ur.UserId
                                                          AND ucs.ProjectId = ur.ProjectId
                                                          AND ucs.CategoryId = ur.CategoryId
                                                          AND ucs.PayPlan = ur.PayPlan
                INNER JOIN webuser.User_Summaries us ON us.UserId = ur.UserId
                                                        AND us.ProjectId = ur.ProjectId
                                                        AND us.PayPlan = ur.PayPlan
                                                        AND us.SummaryName = ur.SummaryName
      WHERE     ur.ProjectId = @ProjectID
                AND ucs.CategorySubGroupCode = '__ALL__'
                AND ucs.PayPlan != 'CCE'
    );