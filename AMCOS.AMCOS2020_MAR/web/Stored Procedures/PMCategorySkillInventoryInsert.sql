CREATE PROC [web].[PMCategorySkillInventoryInsert]
    @SkillId INT,
    @InventoryYear INT,
    @InventoryAmount INT
AS
BEGIN
    IF EXISTS
    (
        SELECT Amount
        FROM webuser.PMCategorySkillInventory
        WHERE SkillId = @SkillId
              AND [Year] = @InventoryYear
    )
    BEGIN
        UPDATE webuser.PMCategorySkillInventory
        SET [Amount] = [Amount] + @InventoryAmount
        WHERE SkillId = @SkillId
              AND [Year] = @InventoryYear;
    END;
    ELSE
    BEGIN
        INSERT INTO webuser.PMCategorySkillInventory
        (
            [SkillId],
            [Year],
            [Amount]
        )
        VALUES
        (@SkillId, @InventoryYear, @InventoryAmount);
    END;
END;