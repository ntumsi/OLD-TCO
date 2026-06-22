-- =============================================
-- Author:		Greg
-- Create date: 04/17/2019
-- Description:	Delete any rows that contain costs for pay plan and category group that only contain unknown step_YOS
-- =============================================
CREATE PROCEDURE [crunch].[DeleteCostsWithUnknownStepYOSOnly]
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM crunch.Costs_AE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_AE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_AE.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_AE.MOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_AE.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_AE.GradeLevel
    );

    DELETE FROM crunch.Costs_AO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_AO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_AO.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_AO.AOC
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_AO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_AO.GradeLevel
    );

    DELETE FROM crunch.Costs_AWO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_AWO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_AWO.Branch
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_AWO.WOMOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_AWO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_AWO.GradeLevel
    );

    DELETE FROM crunch.Costs_NE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NE.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NE.MOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_NE.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NE.GradeLevel
    );

    DELETE FROM crunch.Costs_NO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NO.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NO.AOC
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_NO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NO.GradeLevel
    );

    DELETE FROM crunch.Costs_NWO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NWO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NWO.Branch
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NWO.WOMOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_NWO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NWO.GradeLevel
    );

    DELETE FROM crunch.Costs_RE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_RE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_RE.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_RE.MOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_RE.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_RE.GradeLevel
    );

    DELETE FROM crunch.Costs_RO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_RO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_RO.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_RO.AOC
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_RO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_RO.GradeLevel
    );

    DELETE FROM crunch.Costs_RWO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_RWO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_RWO.Branch
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_RWO.WOMOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_RWO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_RWO.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_NE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_NE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_NE.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_NE.MOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_NE.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_NE.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_NO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_NO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_NO.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_NO.AOC
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_NO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_NO.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_NWO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_NWO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_NWO.Branch
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_NWO.WOMOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_NWO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_NWO.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_RE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_RE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_RE.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_RE.MOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_RE.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_RE.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_RO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_RO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_RO.CMF
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_RO.AOC
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_RO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_RO.GradeLevel
    );

    DELETE FROM crunch.Costs_1ActiveDay_RWO
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_1ActiveDay_RWO.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_1ActiveDay_RWO.Branch
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_1ActiveDay_RWO.WOMOS
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_1ActiveDay_RWO.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_1ActiveDay_RWO.GradeLevel
    );

    DELETE FROM crunch.CostsGG
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = CostsGG.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = CostsGG.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = CostsGG.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeType = CostsGG.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = CostsGG.GradeLevel
    );

    DELETE FROM crunch.CostsGL
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = CostsGL.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = CostsGL.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = CostsGL.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeType = CostsGL.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = CostsGL.GradeLevel
    );

    DELETE FROM crunch.Costs_GS
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_GS.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_GS.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_GS.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_GS.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_GS.GradeLevel
    );

    DELETE FROM crunch.Costs_GSS
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_GSS.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_GSS.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_GSS.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_GSS.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_GSS.GradeLevel
    );

    DELETE FROM crunch.Costs_SES
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_SES.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_SES.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_SES.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_SES.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_SES.GradeLevel
    );

    DELETE FROM crunch.Costs_DB
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_DB.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_DB.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_DB.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_DB.GradeLevel
    );

    DELETE FROM crunch.Costs_DE
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_DE.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_DE.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_DE.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_DE.GradeLevel
    );

    DELETE FROM crunch.Costs_DJ
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_DJ.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_DJ.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_DJ.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_DJ.GradeLevel
    );

    DELETE FROM crunch.Costs_DK
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_DK.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_DK.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_DK.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_DK.GradeLevel
    );


    DELETE FROM crunch.Costs_NH
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NH.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NH.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NH.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NH.GradeLevel
    );

    DELETE FROM crunch.Costs_NJ
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NJ.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NJ.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NJ.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NJ.GradeLevel
    );

    DELETE FROM crunch.Costs_NK
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_NK.PayPlan
              AND InventoryWithUnknownStepYosOnly.CategoryGroupCode = Costs_NK.OccupationalGroupNumber
              AND InventoryWithUnknownStepYosOnly.CategorySubGroupCode = Costs_NK.OccupationalSeriesNumber
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_NK.GradeLevel
    );

    DELETE FROM crunch.Costs_WG
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_WG.PayPlan
              AND InventoryWithUnknownStepYosOnly.WageArea = Costs_WG.WageArea
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_WG.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_WG.GradeLevel
    );

    DELETE FROM crunch.Costs_WL
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_WL.PayPlan
              AND InventoryWithUnknownStepYosOnly.WageArea = Costs_WL.WageArea
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_WL.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_WL.GradeLevel
    );

    DELETE FROM crunch.Costs_WS
    WHERE EXISTS
    (
        SELECT *
        FROM data.InventoryWithUnknownStepYOSOnly InventoryWithUnknownStepYosOnly
        WHERE InventoryWithUnknownStepYosOnly.PayPlan = Costs_WS.PayPlan
              AND InventoryWithUnknownStepYosOnly.WageArea = Costs_WS.WageArea
              AND InventoryWithUnknownStepYosOnly.GradeType = Costs_WS.GradeType
              AND InventoryWithUnknownStepYosOnly.GradeLevel = Costs_WS.GradeLevel
    );

END;