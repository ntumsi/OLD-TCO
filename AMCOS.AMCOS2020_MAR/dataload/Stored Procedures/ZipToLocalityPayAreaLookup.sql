CREATE PROCEDURE [dataload].[ZipToLocalityPayAreaLookup] @AmcosVersionId INT
AS
BEGIN
    SELECT DISTINCT
           a.ZIPCode,
           c.LocalityCode
    FROM data.GetFipsZipByAmcosVersion(@AmcosVersionId) a
        INNER JOIN data.GetLocalityPayAreaByAmcosVersion(@AmcosVersionId) b
            ON a.FIPSCode = b.StateCode + b.CountyCode
        INNER JOIN data.GetLocalityPayByAmcosVersion(@AmcosVersionId) c
            ON c.LocalityCode = b.LocalityCode
    ORDER BY a.ZIPCode;
END;