-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetExtendedYears]
(
    @UIC NVARCHAR(6),
    @UnitLocation NVARCHAR(150),
    @NotSelectedPayPlans NVARCHAR(500),
    @MtoeSyncExtendedDurationFillValue NVARCHAR(25) = 'OTOE',
    @ProjectYearStart INTEGER,
    @ProjectYearDuration INTEGER
)
RETURNS @ExtendedYears TABLE
(
    UIC NVARCHAR(6) NOT NULL,
    AuthorizationDocument NVARCHAR(50) NULL,
    UICTitle VARCHAR(100) NOT NULL,
    PayPlan NVARCHAR(3) NOT NULL,
    CategoryGroupCode NVARCHAR(10) NOT NULL,
    CategorySubgroupCode NVARCHAR(10) NOT NULL,
    LocationId INT NOT NULL,
    LocationText NVARCHAR(150) NOT NULL,
    STRL NVARCHAR(20) NOT NULL,
    GradeLevel TINYINT NOT NULL,
    DependentStatus NVARCHAR(25) NOT NULL,
    NumberOfDependents INT NOT NULL,
    ActiveDutyDays SMALLINT NOT NULL,
    Inventory INT NOT NULL,
    UnitYear NVARCHAR(4) NOT NULL
)
AS
BEGIN;
    DECLARE @FillValue NVARCHAR(4); /* The value to use for the WHERE clause when selecting the unit year */
    DECLARE @LastMtoeUnitYear NVARCHAR(4); /* The maximum unit year, not including OTOE */
    SELECT @LastMtoeUnitYear = web.GetLastMtoeUnitYear(@UIC);
    DECLARE @NumberOfYearsToFill INTEGER; /* How many years do we need to fill? */
    SELECT @NumberOfYearsToFill = @ProjectYearDuration - (@LastMtoeUnitYear - @ProjectYearStart) - 1;
    DECLARE @LastFillYear INTEGER;
    SELECT @LastFillYear = @LastMtoeUnitYear + @NumberOfYearsToFill;

    IF @MtoeSyncExtendedDurationFillValue = 'OTOE'
        SET @FillValue = N'OTOE';
    ELSE
        SELECT @FillValue = @LastMtoeUnitYear;

    WITH cte (UIC, AuthorizationDocument, UICTitle, PayPlan, CategoryGroupCode, CategorySubgroupCode, LocationId,
              LocationText, STRL, GradeLevel, DependentStatus, NumberOfDependents, ActiveDutyDays, Inventory, UnitYear
             )
    AS (SELECT UnitPersonnel.UIC,
               UnitPersonnel.AuthorizationDocument,
               UnitPersonnel.UICTitle,
               UnitPersonnel.PayPlan,
               UnitPersonnel.CategoryGroupCode,
               UnitPersonnel.CategorySubgroupCode,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       LocationId
                   WHEN 'national' THEN
                       -1
                   ELSE
                       -1
               END LocationId,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       UnitPersonnel.LocationText
                   ELSE
                       UnitPersonnel.LocationText
               END LocationText,
               UnitPersonnel.STRL,
               UnitPersonnel.GradeLevel,
               UnitPersonnel.DependentStatus,
               UnitPersonnel.NumberOfDependents,
               UnitPersonnel.ActiveDutyDays,
               UnitPersonnel.Inventory,
               (CONVERT(INTEGER, @LastMtoeUnitYear) + 1) UnitYear
        FROM warehouse.UnitPersonnel UnitPersonnel
        WHERE UnitPersonnel.UIC = @UIC
              AND UnitPersonnel.UnitYear = @FillValue
              AND UnitPersonnel.PayPlan NOT IN
                  (
                      SELECT value FROM STRING_SPLIT(@NotSelectedPayPlans, ',')
                  )
        UNION ALL
        SELECT cte.UIC,
               cte.AuthorizationDocument,
               cte.UICTitle,
               cte.PayPlan,
               cte.CategoryGroupCode,
               cte.CategorySubgroupCode,
               cte.LocationId,
               cte.LocationText,
               cte.STRL,
               cte.GradeLevel,
               cte.DependentStatus,
               cte.NumberOfDependents,
               cte.ActiveDutyDays,
               cte.Inventory,
               cte.UnitYear + 1
        FROM cte
        WHERE UnitYear < @LastFillYear)
    INSERT INTO @ExtendedYears
    (
        UIC,
        AuthorizationDocument,
        UICTitle,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        LocationId,
        LocationText,
        STRL,
        GradeLevel,
        DependentStatus,
        NumberOfDependents,
        ActiveDutyDays,
        Inventory,
        UnitYear
    )
    SELECT cte.UIC,
           cte.AuthorizationDocument,
           cte.UICTitle,
           cte.PayPlan,
           cte.CategoryGroupCode,
           cte.CategorySubgroupCode,
           cte.LocationId,
           cte.LocationText,
           cte.STRL,
           cte.GradeLevel,
           cte.DependentStatus,
           cte.NumberOfDependents,
           cte.ActiveDutyDays,
           cte.Inventory,
           cte.UnitYear
    FROM cte;

    RETURN;
END;