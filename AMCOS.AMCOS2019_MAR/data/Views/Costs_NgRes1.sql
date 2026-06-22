



CREATE VIEW [data].[Costs_NgRes1]
AS
    SELECT PayPlan ,
           CMF AS CategoryGroupCode ,
           MOS AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_NE
    UNION ALL
    SELECT PayPlan ,
           CMF AS CategoryGroupCode ,
           AOC AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_NO
    UNION ALL
    SELECT PayPlan ,
           Branch AS CategoryGroupCode ,
           WOMOS AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_NWO
    UNION ALL
    SELECT PayPlan ,
           CMF AS CategoryGroupCode ,
           MOS AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_RE
    UNION ALL
    SELECT PayPlan ,
           CMF AS CategoryGroupCode ,
           AOC AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_RO
    UNION ALL
    SELECT PayPlan ,
           Branch AS CategoryGroupCode ,
           WOMOS AS CategorySubGroupCode ,
           NULL AS SpecialRateTableNumber ,
           NULL AS WageArea ,
           CostElementId ,
           GradeType ,
           GradeLevel ,
           Amount
    FROM   crunch.Costs_1ActiveDay_RWO;