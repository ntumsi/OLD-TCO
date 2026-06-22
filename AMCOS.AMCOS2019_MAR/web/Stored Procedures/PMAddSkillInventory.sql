


CREATE PROCEDURE [web].[PMAddSkillInventory]
    @UserId VARCHAR(50) ,
    @ProjectId INT ,
    @CategoryId INT ,
    @SkillId INT ,
    @Year INT ,
    @Amount INT
AS
    IF EXISTS (   SELECT 0
                  FROM   webuser.PMCategorySkillInventory
                  WHERE  UserId = @UserId
                         AND ProjectId = @ProjectId
                         AND CategoryId = @CategoryId
                         AND SkillId = @SkillId
                         AND [Year] = @Year
              )
        BEGIN

            UPDATE webuser.PMCategorySkillInventory
            SET    Amount = Amount + @Amount
            WHERE  UserId = @UserId
                   AND ProjectId = @ProjectId
                   AND CategoryId = @CategoryId
                   AND SkillId = @SkillId
                   AND [Year] = @Year;

            SELECT [Id]
            FROM   webuser.PMCategorySkillInventory
            WHERE  UserId = @UserId
                   AND ProjectId = @ProjectId
                   AND CategoryId = @CategoryId
                   AND SkillId = @SkillId
                   AND [Year] = @Year;
        END;
    ELSE
        BEGIN
            INSERT INTO webuser.PMCategorySkillInventory (   UserId ,
                                                             ProjectId ,
                                                             CategoryId ,
                                                             SkillId ,
                                                             [Year] ,
                                                             Amount
                                                         )
            VALUES ( @UserId ,
                     @ProjectId ,
                     @CategoryId ,
                     @SkillId ,
                     @Year ,
                     @Amount
                   );
            SELECT @@IDENTITY;
        END;