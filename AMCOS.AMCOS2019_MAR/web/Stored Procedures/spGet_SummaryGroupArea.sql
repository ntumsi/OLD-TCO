
CREATE PROCEDURE [web].[spGet_SummaryGroupArea] @PayPlan NVARCHAR(3)
AS
BEGIN
    IF @PayPlan = 'CCE'
    BEGIN
        SELECT SummaryId,
               [Name] AS SummaryDescription
        FROM lookup.CostSummary
        WHERE (PayPlan = 'CCE');

        SELECT DISTINCT
               CategoryGroupCode,
               CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
        FROM data.CategoryGroup
        WHERE PayPlan = @PayPlan
        ORDER BY CategoryGroupCode;

    END;
    ELSE
    BEGIN
        SELECT SummaryId,
               [Name] AS SummaryDescription
        FROM lookup.CostSummary
        WHERE (PayPlan = @PayPlan)
        UNION
        SELECT 0,
               '-ALL Cost-';

        SELECT DISTINCT
               CategoryGroupCode,
               CategoryGroupCode + ' : ' + CategoryGroupDescription AS CategoryGroupDescription
        FROM data.CategoryGroupWithInventory
        WHERE PayPlan = @PayPlan
              AND CategoryGroupCode IN
                  (
                      SELECT DISTINCT
                             CategoryGroupCode
                      FROM data.Inventory
                      WHERE PayPlan = @PayPlan
                  )
        UNION
        SELECT '__ALL__',
               '-ALL-'
        ORDER BY CategoryGroupCode;
    END;
END;