-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[LoadGFEBSInventory]
AS
BEGIN
    SET NOCOUNT ON;

    /* GP */
    BEGIN
        TRUNCATE TABLE load_inventory.Inventory_CivilianGP2019;
        INSERT INTO load_inventory.Inventory_CivilianGP2019
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeType,
            GradeLevel,
            Step,
            YOS,
            Inventory
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               PayPlan AS GradeType,
               GradeLevel,
               Step AS Step,
               NULL AS YOS,
               COUNT(DISTINCT PersonnelNumber) AS Inventory
        FROM load_GFEBS.Processed
        WHERE PayPlan IN ( 'GP' )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 StateCountry,
                 FunctionalAreaCode,
                 CostCenterCode,
                 GradeLevel,
                 Step;
    END;

    /* DB,DE,DJ,DK */
    BEGIN
        TRUNCATE TABLE load_inventory.Inventory_CivilianDemonstration2019;
        INSERT INTO load_inventory.Inventory_CivilianDemonstration2019
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeType,
            GradeLevel,
            Step,
            Inventory
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               PayPlan AS GradeType,
               GradeLevel,
               NULL AS Step,
               COUNT(DISTINCT PersonnelNumber) AS Inventory
        FROM load_GFEBS.Processed
        WHERE PayPlan IN ( 'DB', 'DE', 'DJ', 'DK' )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 StateCountry,
                 FunctionalAreaCode,
                 CostCenterCode,
                 GradeLevel,
                 Step;
    END;

    /* NH,NJ,NK */
    BEGIN
        TRUNCATE TABLE load_inventory.Inventory_CivilianAcquisition2019;
        INSERT INTO load_inventory.Inventory_CivilianAcquisition2019
        (
            PayPlan,
            OccupationalGroupNumber,
            OccupationalSeriesNumber,
            StateCountry,
            FunctionalAreaCode,
            CostCenterCode,
            GradeType,
            GradeLevel,
            YOS,
            Inventory
        )
        SELECT PayPlan,
               OccupationalGroupNumber,
               OccupationalSeriesNumber,
               StateCountry,
               FunctionalAreaCode,
               CostCenterCode,
               PayPlan AS GradeType,
               GradeLevel,
               NULL AS YOS,
               COUNT(DISTINCT PersonnelNumber) AS Inventory
        FROM load_GFEBS.Processed
        WHERE PayPlan IN ( 'NH', 'NJ', 'NK' )
        GROUP BY PayPlan,
                 OccupationalGroupNumber,
                 OccupationalSeriesNumber,
                 StateCountry,
                 FunctionalAreaCode,
                 CostCenterCode,
                 GradeLevel,
                 Step;
    END;

END;