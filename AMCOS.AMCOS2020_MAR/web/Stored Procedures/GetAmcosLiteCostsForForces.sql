CREATE PROCEDURE [web].[GetAmcosLiteCostsForForces]
    @InflationConversion NVARCHAR(25),
    @InflationYear NVARCHAR(4),
    @AmcosVersionId INTEGER = 202001
AS
BEGIN
    /* WG; Default Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'WG',                            -- nvarchar(3)
                               @CostSummaryName = N'Default',               -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* WL; Default Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'WL',                            -- nvarchar(3)
                               @CostSummaryName = N'Default',               -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* WS; Default Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'WS',                            -- nvarchar(3)
                               @CostSummaryName = N'Default',               -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Contractor Cost Estimate; 11-9199; DC-VA-MD-WV */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'CCE',                           -- nvarchar(3)
                               @CostSummaryName = N'Default',               -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'11-9199',          -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* GS; Rest of U.S.; Default Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'GS',                            -- nvarchar(3)
                               @CostSummaryName = N'Default',               -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = 1007,                          -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Enlisted; Ancillary Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AE',                            -- nvarchar(3)
                               @CostSummaryName = N'Ancillary',             -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Enlisted; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AE',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; Ancillary Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Ancillary',             -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Warrant Officer; Ancillary Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AWO',                           -- nvarchar(3)
                               @CostSummaryName = N'Ancillary',             -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Warrant Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AWO',                           -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army National Guard Enlisted; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'NE',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army National Guard Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'NO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army National Guard Warrant Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'NWO',                           -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army Reserve Enlisted; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'RE',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army Reserve Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'RO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Army Reserve Warrant Officer; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'RWO',                           -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'-1',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 15B; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'15',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'15B',              -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Warrant Officer; 152H; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AWO',                           -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'15',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'152H',             -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 60; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'60',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 61; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'61',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 62; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'62',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 63; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'63',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 64; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'64',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 65D; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'65',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'65D',              -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 66; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'66',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'-1',               -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 67E; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'67',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'67E',              -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 67F; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'67',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'67F',              -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit

    /* Active Duty Army Officer; 73B; Detailed Cost Summary */
    EXEC web.GetAmcosLiteCosts @PayPlan = N'AO',                            -- nvarchar(3)
                               @CostSummaryName = N'Detailed',              -- nvarchar(50)
                               @CategoryGroupCode = N'73',                  -- nvarchar(4)
                               @CategorySubgroupCode = N'73B',              -- nvarchar(5)
                               @CareerProgramNumber = N'-1',                -- nchar(2)
                               @LocationId = -1,                            -- int
                               @STRL = N'-1',                               -- nvarchar(20)
                               @DependentStatus = N'-1',                   -- nvarchar(25)
                               @InflationConversion = @InflationConversion, -- nvarchar(25)
                               @InflationYear = @InflationYear,             -- nvarchar(4)
                               @IncludeVisualizationData = 0,
                               @AmcosVersionId = @AmcosVersionId,           -- int
                               @Debug = NULL;                               -- bit
END;