
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dataload].[TruncateTrainingData]
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE load_training.TrainingArmy;
    TRUNCATE TABLE load_training.TrainingCMF;
    TRUNCATE TABLE load_training.TrainingMOS;
    TRUNCATE TABLE lookup.WeaponSystem;
    INSERT INTO lookup.WeaponSystem
    (
        WeaponSystemName
    )
    VALUES
    (N'Not Applicable' -- WeaponSystemName - nvarchar(50)
        );

END;