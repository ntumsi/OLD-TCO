-- =============================================
-- Author:		
-- Create date: 
-- Description:	Check for duplicates before copying a project category
-- =============================================
CREATE FUNCTION [web].[ProjectCategoryCount]
    (
      @ProjectId INTEGER ,
      @FromCategoryId INTEGER ,
      @ToCategoryId INTEGER
    )
RETURNS INT
AS
    BEGIN
        DECLARE @Result INT;

        SELECT  @Result = COUNT(*)
        FROM    ( SELECT    a.UserId,
                            a.ProjectId,
                            a.CategoryId,
                            a.SkillId,
                            a.PayPlan,
                            a.CategoryGroupCode,
                            a.CategorySubGroupCode,
                            a.GradeType,
                            a.GradeLevel,
                            a.Type,
                            a.AreaCode,
                            a.LocalityId,
                            a.SpecialRateTableNumber,
                            a.StateCountry,
                            a.FunctionalAreaCode,
                            a.CostCenterCode,
                            a.activeDays,
                            a.overheadPct
                  FROM      webuser.PMCategorySkill a
                  WHERE     a.ProjectId = @ProjectId
                            AND a.CategoryId = @FromCategoryId
                ) a
                LEFT JOIN ( SELECT  a.UserId,
                                    a.ProjectId,
                                    a.CategoryId,
                                    a.SkillId,
                                    a.PayPlan,
                                    a.CategoryGroupCode,
                                    a.CategorySubGroupCode,
                                    a.GradeType,
                                    a.GradeLevel,
                                    a.Type,
                                    a.AreaCode,
                                    a.LocalityId,
                                    a.SpecialRateTableNumber,
                                    a.StateCountry,
                                    a.FunctionalAreaCode,
                                    a.CostCenterCode,
                                    a.activeDays,
                                    a.overheadPct
                            FROM    webuser.PMCategorySkill a
                            WHERE   a.ProjectId = @ProjectId
                                    AND a.CategoryId = @ToCategoryId
                          ) b ON a.ProjectId = b.ProjectId
                                 AND a.PayPlan = b.PayPlan
                                 AND a.CategorySubGroupCode = b.CategorySubGroupCode
                                 AND ISNULL(a.AreaCode, 0) = ISNULL(b.AreaCode,
                                                              0)
                                 AND ISNULL(a.LocalityID, 0) = ISNULL(b.LocalityID,
                                                              0)
                                 AND a.GradeLevel = b.GradeLevel
                                 AND ISNULL(a.overheadPct, 0) = ISNULL(b.overheadPct,
                                                              0)
        WHERE   b.ProjectId IS NULL;

        RETURN @Result;

    END;