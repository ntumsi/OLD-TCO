


CREATE VIEW [data].[CostsWithDescriptions]
AS
SELECT Costs.[PayPlan],
       Costs.[CategoryGroupCode],
       CategorySubgroup.CategoryGroupDescription,
       Costs.[CategorySubGroupCode],
       CategorySubgroup.CategorySubGroupDescription,
       Costs.[SpecialRateTableNumber],
       Costs.[WageArea],
       WageArea.Description AS WageAreaName,
       Costs.[StateCountry],
       Costs.[FunctionalAreaCode],
       FunctionalArea.FunctionalAreaText,
       Costs.[CostCenterCode],
       CostCenter.CostCenterText,
       Costs.[CostElementId],
       Costs.[AppropriationGroup],
       Costs.[APPN],
       Costs.[CostElementCategory],
       Costs.[CostElementName],
       Costs.[Description],
       Costs.[ArmyCesTitle],
       Costs.[OsdCapeCesTitle],
       Costs.[showOrder],
       Costs.[GradeType],
       Costs.[GradeLevel],
       WeaponSystem.WeaponSystemName,
       Costs.[Amount]
FROM [data].[Costs] Costs
    LEFT OUTER JOIN lookup.GFEBS_CostCenter CostCenter
        ON Costs.CostCenterCode = CostCenter.CostCenterCode
    LEFT OUTER JOIN lookup.GFEBS_FunctionalArea AS FunctionalArea
        ON Costs.FunctionalAreaCode = FunctionalArea.FunctionalAreaCode
    LEFT OUTER JOIN lookup.WageArea AS WageArea
        ON Costs.WageArea = WageArea.WageArea
    LEFT OUTER JOIN data.CategorySubgroup CategorySubgroup
        ON CategorySubgroup.PayPlan = Costs.PayPlan
           AND CategorySubgroup.CategoryGroupCode = Costs.CategoryGroupCode
           AND CategorySubgroup.CategorySubGroupCode = Costs.CategorySubGroupCode
    LEFT OUTER JOIN lookup.WeaponSystem WeaponSystem
        ON WeaponSystem.WeaponSystemId = Costs.WeaponSystemId;