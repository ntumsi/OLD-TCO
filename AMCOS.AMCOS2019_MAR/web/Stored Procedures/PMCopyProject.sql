

CREATE PROCEDURE [web].[PMCopyProject]
    (
        @ProjectId INT ,
        @ProjectName VARCHAR(50) ,
        @Description TEXT
    )
AS
    DECLARE @SummaryID INT;
    DECLARE @CategoryId INT;
    DECLARE @SkillId INT;
    DECLARE @NewProjectID INT;
    DECLARE @NewSummaryID INT;
    DECLARE @NewCategoryID INT;
    DECLARE @NewSkillID INT;
    DECLARE @oldProjectName VARCHAR(50);

    SELECT @oldProjectName = ProjectName
    FROM   webuser.PMProject
    WHERE  ProjectId = @ProjectId;

    INSERT INTO webuser.PMProject (   UserId ,
                                      ProjectName ,
                                      YearStart ,
                                      YearDuration ,
                                      ProjectCreator ,
                                      ProjectType ,
                                      ReserveDaysInActive ,
                                      ReserveDaysActive ,
                                      DiscountRate ,
                                      CreateDate ,
                                      LastUpdate ,
                                      Description
                                  )
                SELECT UserId ,
                       @ProjectName ,
                       YearStart ,
                       YearDuration ,
                       ProjectCreator ,
                       ProjectType ,
                       ReserveDaysInActive ,
                       ReserveDaysActive ,
                       DiscountRate ,
                       GETDATE() ,
                       GETDATE() ,
                       @Description
                FROM   webuser.PMProject
                WHERE  ProjectId = @ProjectId;

    SELECT @NewProjectID = @@IDENTITY;


    -- Copy Summary data
    DECLARE cSummary CURSOR FOR
        SELECT   SummaryId
        FROM     webuser.User_Summaries
        WHERE    ProjectId = @ProjectId
        ORDER BY SummaryId;

    OPEN cSummary;

    FETCH cSummary
    INTO @SummaryID;

    WHILE @@FETCH_STATUS = 0
        BEGIN

            INSERT INTO webuser.User_Summaries (   UserId ,
                                                   ProjectId ,
                                                   PayPlan ,
                                                   Type ,
                                                   SummaryName ,
                                                   InReport
                                               )
                        SELECT UserId ,
                               @NewProjectID ,
                               PayPlan ,
                               Type ,
                               SummaryName ,
                               InReport
                        FROM   webuser.User_Summaries
                        WHERE  ProjectId = @ProjectId
                               AND SummaryId = @SummaryID;

            SELECT @NewSummaryID = @@IDENTITY;

            INSERT INTO webuser.User_SummaryElements (   UserId ,
                                                         ProjectId ,
                                                         SummaryId ,
                                                         CostElementId
                                                     )
                        SELECT UserId ,
                               @NewProjectID ,
                               @NewSummaryID ,
                               CostElementId
                        FROM   webuser.User_SummaryElements
                        WHERE  ProjectId = @ProjectId
                               AND SummaryId = @SummaryID;

            FETCH cSummary
            INTO @SummaryID;
        END;

    CLOSE cSummary;
    DEALLOCATE cSummary;


    -- Copy Category Data
    DECLARE cCategory CURSOR FOR
        SELECT   CategoryId
        FROM     webuser.PMCategory
        WHERE    ProjectId = @ProjectId
        ORDER BY CategoryId;

    OPEN cCategory;

    FETCH cCategory
    INTO @CategoryId;

    WHILE @@FETCH_STATUS = 0
        BEGIN

            INSERT INTO webuser.PMCategory (   UserId ,
                                               ProjectId ,
                                               CategoryName
                                           )
                        SELECT UserId ,
                               @NewProjectID ,
                               ( CASE WHEN CategoryName = @oldProjectName THEN
                                          @ProjectName
                                      ELSE CategoryName
                                 END
                               )
                        FROM   webuser.PMCategory
                        WHERE  ProjectId = @ProjectId
                               AND CategoryId = @CategoryId;

            SELECT @NewCategoryID = @@IDENTITY;

            DECLARE cSkills CURSOR FOR
                SELECT   SkillId
                FROM     webuser.PMCategorySkill
                WHERE    ProjectId = @ProjectId
                         AND CategoryId = @CategoryId
                ORDER BY SkillId;

            OPEN cSkills;

            FETCH cSkills
            INTO @SkillId;

            WHILE @@FETCH_STATUS = 0
                BEGIN

                    INSERT INTO webuser.PMCategorySkill (   UserId ,
                                                            ProjectId ,
                                                            CategoryId ,
                                                            PayPlan ,
                                                            CategoryGroupCode ,
                                                            CategorySubGroupCode ,
                                                            Type ,
                                                            LocalityId ,
                                                            GradeType ,
                                                            GradeLevel ,
                                                            AreaCode ,
                                                            activeDays ,
                                                            overheadPct
                                                        )
                                SELECT UserId ,
                                       @NewProjectID ,
                                       @NewCategoryID ,
                                       PayPlan ,
                                       CategoryGroupCode ,
                                       CategorySubGroupCode ,
                                       Type ,
                                       LocalityId ,
                                       GradeType ,
                                       GradeLevel ,
                                       AreaCode ,
                                       activeDays ,
                                       overheadPct
                                FROM   webuser.PMCategorySkill
                                WHERE  ProjectId = @ProjectId
                                       AND CategoryId = @CategoryId
                                       AND SkillId = @SkillId;

                    SELECT @NewSkillID = @@IDENTITY;

                    INSERT INTO webuser.PMCategorySkillInventory (   UserId ,
                                                                     ProjectId ,
                                                                     CategoryId ,
                                                                     SkillId ,
                                                                     [Year] ,
                                                                     Amount
                                                                 )
                                SELECT UserId ,
                                       @NewProjectID ,
                                       @NewCategoryID ,
                                       @NewSkillID ,
                                       [Year] ,
                                       Amount
                                FROM   webuser.PMCategorySkillInventory
                                WHERE  ProjectId = @ProjectId
                                       AND CategoryId = @CategoryId
                                       AND SkillId = @SkillId;

                    FETCH cSkills
                    INTO @SkillId;
                END;

            CLOSE cSkills;
            DEALLOCATE cSkills;

            FETCH cCategory
            INTO @CategoryId;
        END;

    CLOSE cCategory;
    DEALLOCATE cCategory;


    RETURN;