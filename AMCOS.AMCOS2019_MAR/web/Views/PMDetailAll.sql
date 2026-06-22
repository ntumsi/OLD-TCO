
CREATE VIEW [web].[PMDetailAll]
AS
    SELECT  p.[UserId] ,
            p.[ProjectId] ,
            [ProjectName] ,
            [YearStart] ,
            [YearDuration] ,
            [ProjectType] ,
            [ReserveDaysInActive] ,
            [ReserveDaysActive] ,
            [Description] ,
            [DiscountRate] ,
            CategoryName ,
            [PayPlan] ,
            [CategoryGroupCode] ,
            [CategorySubGroupCode] ,
            [Type] ,
            [AreaCode] ,
            [LocalityId] ,
            [SpecialRateTableNumber] ,
            [StateCountry] ,
            [GradeType] ,
            [GradeLevel] ,
            [activeDays] ,
            [overheadPct] ,
            [FunctionalAreaCode] ,
            [CostCenterCode] ,
            [Year] AS InventoryYear ,
            Amount AS Inventory
    FROM    webuser.PMProject p
            INNER JOIN webuser.PMCategory c ON p.UserId = c.UserId
                                               AND p.ProjectId = c.ProjectId
            INNER JOIN webuser.PMCategorySkill cs ON c.UserId = cs.UserId
                                                     AND c.ProjectId = cs.ProjectId
                                                     AND c.CategoryId = cs.CategoryId
            INNER JOIN webuser.PMCategorySkillInventory csi ON cs.UserId = csi.UserId
                                                              AND cs.ProjectId = csi.ProjectId
                                                              AND cs.SkillId = csi.SkillId;