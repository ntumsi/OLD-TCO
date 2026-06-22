CREATE PROCEDURE [dataload].[UicLookup]
AS
BEGIN
    SELECT UIC,
           COUNTRY,
           ZIP
    FROM lookup.UICLocation a
    WHERE EffectiveDate = (SELECT MAX(EffectiveDate) FROM lookup.UICLocation b WHERE a.UIC = b.UIC) 
    ORDER BY UIC;
END;
