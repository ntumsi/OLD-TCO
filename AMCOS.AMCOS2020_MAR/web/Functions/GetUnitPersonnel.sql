-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetUnitPersonnel]
(
    @CategoryId INT,
    @UIC NVARCHAR(6),
    @NotSelectedPayPlans NVARCHAR(500),
    @UnitLocation NVARCHAR(150),
    @MtoeProjectInventoryYear NVARCHAR(25) = NULL,
    @MtoeSyncExtendedDurationFillValue NVARCHAR(25) = 'OTOE',
    @OverheadPercent FLOAT = 150
)
RETURNS @UnitPersonnel TABLE
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
    OverheadPercent FLOAT NOT NULL,
    Inventory INT NOT NULL,
    UnitYear NVARCHAR(4) NOT NULL
)
AS
BEGIN

    DECLARE @LocationDisplayName NVARCHAR(100) = NULL;
    IF TRY_CONVERT(INT, @UnitLocation) IS NOT NULL
    BEGIN
        SELECT @LocationDisplayName = web.GetLocationDisplayName(@UnitLocation);
    END;

    DECLARE @AuthorizationDocument NVARCHAR(50);
    SELECT @AuthorizationDocument = web.GetUnitAuthorizationDocument(@UIC);
    IF CHARINDEX('TDA', @AuthorizationDocument) > 0
    BEGIN
        INSERT INTO @UnitPersonnel
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
            OverheadPercent,
            Inventory,
            UnitYear
        )
        SELECT UnitPersonnel.UIC,
               UnitPersonnel.AuthorizationDocument,
               UnitPersonnel.UICTitle,
               UnitPersonnel.PayPlan,
               UnitPersonnel.CategoryGroupCode,
               UnitPersonnel.CategorySubgroupCode,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       UnitPersonnel.LocationId
                   WHEN 'national' THEN
                       -1
                   ELSE
                       ISNULL(XwalkInstallationName.LocationId, -1)
               END LocationId,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       LocationText
                   WHEN 'national' THEN
                       'All'
                   ELSE
                       ISNULL(web.GetLocationDisplayName(XwalkInstallationName.LocationId), 'All')
               END LocationText,
               UnitPersonnel.STRL,
               UnitPersonnel.GradeLevel,
               UnitPersonnel.DependentStatus,
               UnitPersonnel.NumberOfDependents,
               UnitPersonnel.ActiveDutyDays,
               CASE UnitPersonnel.PayPlan
                   WHEN 'CCE' THEN
                       @OverheadPercent
                   ELSE
                       -1
               END OverheadPercent,
               UnitPersonnel.Inventory,
               '0'
        FROM warehouse.UnitPersonnel UnitPersonnel
            LEFT OUTER JOIN web.GetAllLocationIdByInstallation(@LocationDisplayName) XwalkInstallationName
                ON XwalkInstallationName.PayPlan = UnitPersonnel.PayPlan
        WHERE UIC = @UIC
              AND UnitPersonnel.PayPlan NOT IN
                  (
                      SELECT value FROM STRING_SPLIT(@NotSelectedPayPlans, ',')
                  );
    END;
    ELSE
    BEGIN
        INSERT INTO @UnitPersonnel
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
            OverheadPercent,
            Inventory,
            UnitYear
        )
        SELECT UnitPersonnel.UIC,
               UnitPersonnel.AuthorizationDocument,
               UnitPersonnel.UICTitle,
               UnitPersonnel.PayPlan,
               UnitPersonnel.CategoryGroupCode,
               UnitPersonnel.CategorySubgroupCode,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       UnitPersonnel.LocationId
                   WHEN 'national' THEN
                       -1
                   ELSE
                       ISNULL(XwalkInstallationName.LocationId, -1)
               END LocationId,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       LocationText
                   WHEN 'national' THEN
                       'All'
                   ELSE
                       ISNULL(web.GetLocationDisplayName(XwalkInstallationName.LocationId), 'All')
               END LocationText,
               UnitPersonnel.STRL,
               UnitPersonnel.GradeLevel,
               UnitPersonnel.DependentStatus,
               UnitPersonnel.NumberOfDependents,
               UnitPersonnel.ActiveDutyDays,
               CASE UnitPersonnel.PayPlan
                   WHEN 'CCE' THEN
                       @OverheadPercent
                   ELSE
                       -1
               END OverheadPercent,
               UnitPersonnel.Inventory,
               UnitPersonnel.UnitYear
        FROM web.GetSacsYears(@UIC, @UnitLocation, @NotSelectedPayPlans, @MtoeProjectInventoryYear) UnitPersonnel
            LEFT OUTER JOIN web.GetAllLocationIdByInstallation(@LocationDisplayName) XwalkInstallationName
                ON XwalkInstallationName.PayPlan = UnitPersonnel.PayPlan
        UNION ALL
        SELECT UnitPersonnel.UIC,
               UnitPersonnel.AuthorizationDocument,
               UnitPersonnel.UICTitle,
               UnitPersonnel.PayPlan,
               UnitPersonnel.CategoryGroupCode,
               UnitPersonnel.CategorySubgroupCode,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       UnitPersonnel.LocationId
                   WHEN 'national' THEN
                       -1
                   ELSE
                       ISNULL(XwalkInstallationName.LocationId, -1)
               END LocationId,
               CASE @UnitLocation
                   WHEN 'unchanged' THEN
                       LocationText
                   WHEN 'national' THEN
                       'All'
                   ELSE
                       ISNULL(web.GetLocationDisplayName(XwalkInstallationName.LocationId), 'All')
               END LocationText,
               UnitPersonnel.STRL,
               UnitPersonnel.GradeLevel,
               UnitPersonnel.DependentStatus,
               UnitPersonnel.NumberOfDependents,
               UnitPersonnel.ActiveDutyDays,
               CASE UnitPersonnel.PayPlan
                   WHEN 'CCE' THEN
                       @OverheadPercent
                   ELSE
                       -1
               END OverheadPercent,
               UnitPersonnel.Inventory,
               UnitPersonnel.UnitYear
        FROM web.GetExtendedYears(
                                     @UIC,
                                     @UnitLocation,
                                     @NotSelectedPayPlans,
                                     @MtoeSyncExtendedDurationFillValue,
                                     web.GetProjectYearStart(@CategoryId),
                                     web.GetProjectYearDuration(@CategoryId)
                                 ) UnitPersonnel
            INNER JOIN web.GetAllLocationIdByInstallation(@LocationDisplayName) XwalkInstallationName
                ON XwalkInstallationName.PayPlan = UnitPersonnel.PayPlan;
    END;

    RETURN;
END;