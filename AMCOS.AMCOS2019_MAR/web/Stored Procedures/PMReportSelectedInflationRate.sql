

CREATE PROCEDURE [web].[PMReportSelectedInflationRate]
(
    @ProjectID INT,
    @PayPlans NVARCHAR(100)
)
AS
BEGIN

    DECLARE @SelectedPayPlans TABLE
    (
        PayPlan NVARCHAR(4) NULL
    );

    INSERT INTO @SelectedPayPlans
    (
        PayPlan
    )
    SELECT value
    FROM STRING_SPLIT(@PayPlans, ',')
    WHERE RTRIM(value) <> '';

    DECLARE @MinYear INT;
    SELECT @MinYear = MIN(i.[Year] + p.YearStart)
    FROM webuser.PMCategory c
        JOIN webuser.PMCategorySkill s
            ON c.UserId = s.UserId
               AND c.ProjectId = s.ProjectId
               AND c.CategoryId = s.CategoryId
        JOIN webuser.PMProject p
            ON c.ProjectId = p.ProjectId
        JOIN webuser.PMCategorySkillInventory i
            ON s.SkillId = i.SkillId
        JOIN @SelectedPayPlans SelectedPayPlans
            ON s.PayPlan = SelectedPayPlans.PayPlan
    WHERE i.[Year] < p.YearDuration
          AND c.ProjectId = @ProjectID;

    DECLARE @MaxYear INT;
    SELECT @MaxYear = MAX(i.[Year] + p.YearStart)
    FROM webuser.PMCategory c
        JOIN webuser.PMCategorySkill s
            ON c.UserId = s.UserId
               AND c.ProjectId = s.ProjectId
               AND c.CategoryId = s.CategoryId
        JOIN webuser.PMProject p
            ON c.ProjectId = p.ProjectId
        JOIN webuser.PMCategorySkillInventory i
            ON s.SkillId = i.SkillId
        JOIN @SelectedPayPlans SelectedPayPlans
            ON s.PayPlan = SelectedPayPlans.PayPlan
    WHERE i.[Year] < p.YearDuration
          AND c.ProjectId = @ProjectID;

    SELECT Year,
           [Army CivPay] CivPay,
           [OMA] [OMA-CIV],
           [OMDW],
           [Federal OM] [FED-OM],
           [MPA],
           [MPA Non-Pay] [MPA NonPay],
           [OMA] [OMA-MIL],
           [OMDW],
           [Federal OM] [FED-OM],
           [NGPA],
           [OMNG],
           [RPA],
           [OMAR],
           [OMA] [OMA-CCE]
    FROM
    (
        SELECT Year,
               Appropriation,
               Amount
        FROM lookup.JicInflationRates
        WHERE ConversionType = 'ThenToThen'
              AND Year
              BETWEEN @MinYear AND @MaxYear
    ) AS SourceTable
    PIVOT
    (
        SUM(Amount)
        FOR Appropriation IN ([Army CivPay], [Federal OM], [MPA], [MPA Non-Pay], [NGPA], [OMA], [OMA_1], [OMAR],
                              [OMAR_1], [OMDW], [OMNG], [OMNG_1], [RPA]
                             )
    ) AS InflationByYear
    ORDER BY Year;












END;