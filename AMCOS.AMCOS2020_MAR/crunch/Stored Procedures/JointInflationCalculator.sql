-- =============================================
-- Author:Dan Hogan  
-- Create date: Apr 2021
-- 
-- Description:      Populates the legacy and new JIC tables with the latest data
-- release of the latest AmcosVersionId be present in lookup.AmcosVersionId table

-- =============================================
CREATE PROCEDURE [crunch].[JointInflationCalculator]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @commonMinBaseYear NVARCHAR(4) =
            (
                SELECT MAX(myyear)
                FROM
                (
                    SELECT MIN(BaseYear) AS myyear,
                           Appropriation
                    FROM data.AsafmcJointInflationRates
                    WHERE BaseYear <> '197T' --this could mess with the min calc
                    GROUP BY Appropriation
                ) AS a
            );


    DECLARE @commonMinTargetYear NVARCHAR(4) =
            (
                SELECT MAX(myyear)
                FROM
                (
                    SELECT MIN(TargetYear) AS myyear,
                           Appropriation
                    FROM data.AsafmcJointInflationRates
                    WHERE TargetYear <> '197T' --this could mess with the min calc
                    GROUP BY Appropriation
                ) AS a
            );

    DELETE FROM warehouse.JointInflationCalculator;
    INSERT INTO warehouse.JointInflationCalculator
    (
        ConversionType,
        BaseYear,
        TargetYear,
        Appropriation,
        Amount
    )
    SELECT ConversionType,
           BaseYear,
           TargetYear,
           Appropriation,
           Amount
    FROM data.AsafmcJointInflationRates
    WHERE

        --only the latest version
        AmcosVersionId IN
        (
            SELECT MAX(AmcosVersionId) FROM data.AsafmcJointInflationRates
        )
        --only the common minimum base year and targetyear
        AND BaseYear >= @commonMinBaseYear
        AND TargetYear >= @commonMinTargetYear;

    --ALTER TABLE [webuser].[PCSProject] WITH CHECK
    --ADD CONSTRAINT [FK_JICInflationRates]
    --    FOREIGN KEY (
    --                    [ConversionType],
    --                    [Year],
    --                    [Appropriation],
    --                    [AmcosVersionId]
    --                )
    --    REFERENCES [lookup].[JicInflationRates] (
    --                                                [ConversionType],
    --                                                [Year],
    --                                                [Appropriation],
    --                                                [AmcosVersionId]
    --                                            );

    --ALTER TABLE [webuser].[PCSProject] CHECK CONSTRAINT [FK_JICInflationRates];


    --this is the legacy lookup table to eventually be supersceded by the table above
    -- we keep it for now to avoid a bunch of programming changes right before the major spring 2021 release
    DELETE FROM lookup.JicInflationRates
    WHERE AmcosVersionId =
    (
        SELECT MAX(AmcosVersionId) FROM lookup.AMCOSVersion
    );
    INSERT INTO lookup.JicInflationRates
    (
        ConversionType,
        [Year],
        Appropriation,
        Amount,
        AmcosVersionId
    )
    SELECT ConversionType,
           TargetYear,
           Appropriation,
           Amount,
           AmcosVersionId
    FROM data.AsafmcJointInflationRates
    WHERE
        --no 197T as we don't use it and it messes up min/max calculations
        TargetYear <> '197T'
        --only the latest version
        AND AmcosVersionId IN
            (
                SELECT MAX(AmcosVersionId) FROM data.AsafmcJointInflationRates
            )
        --only the current release base year
        AND BaseYear =
        (
            SELECT LEFT(MAX(AmcosVersionId), 4)FROM lookup.AMCOSVersion
        )
        AND TargetYear >= @commonMinTargetYear;
END;