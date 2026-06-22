
CREATE PROCEDURE [web].[PMAddSkillInventory]
    @SkillId INT,
    @Year INT,
    @Amount INT
AS
IF EXISTS
(
    SELECT 0
    FROM webuser.PMCategorySkillInventory
    WHERE SkillId = @SkillId
          AND [Year] = @Year
)
BEGIN

    UPDATE webuser.PMCategorySkillInventory
    SET Amount = Amount + @Amount
    WHERE SkillId = @SkillId
          AND [Year] = @Year;

    SELECT InventoryId
    FROM webuser.PMCategorySkillInventory
    WHERE SkillId = @SkillId
          AND [Year] = @Year;
END;
ELSE
BEGIN
    INSERT INTO webuser.PMCategorySkillInventory
    (
        SkillId,
        [Year],
        Amount
    )
    VALUES
    (@SkillId, @Year, @Amount);
    SELECT @@IDENTITY;
END;