-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE UpdateCostElementAppropriationGroup
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    --Active
    UPDATE lookup.CostElement
    SET AppropriationGroup = 'ARMY'
    WHERE APPN IN ( 'MPA', 'MPA Non-Pay', 'OMA', 'OMA_1' )
          AND PayPlan IN ( 'AE', 'AO', 'AWO' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'DoD'
    WHERE APPN = 'OMDW'
          AND PayPlan IN ( 'AE', 'AO', 'AWO' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'FEDERAL'
    WHERE UPPER(APPN) LIKE 'FEDERAL%'
          AND PayPlan IN ( 'AE', 'AO', 'AWO' );

    --ARNG & USAR
    UPDATE lookup.CostElement
    SET AppropriationGroup = 'PA'
    WHERE APPN LIKE '%PA%'
          AND PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'OM'
    WHERE APPN LIKE '%OM%'
          AND PayPlan IN ( 'NE', 'NO', 'NWO', 'RE', 'RO', 'RWO' );


    UPDATE lookup.CostElement
    SET AppropriationGroup = 'ARMY'
    WHERE (
              APPN LIKE 'ARMY%'
              OR APPN = 'OMA'
          )
          AND PayPlan IN ( 'SES', 'WG', 'WL', 'WS' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'FEDERAL'
    WHERE APPN LIKE 'FEDERAL%'
          AND PayPlan IN ( 'SES', 'WG', 'WL', 'WS' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'ARMY'
    WHERE (
              APPN LIKE 'Army%'
              OR APPN = 'OMA'
          )
          AND PayPlan IN ( 'DB', 'DE', 'DJ', 'DK', 'GP', 'NH', 'NJ', 'NK' );

    UPDATE lookup.CostElement
    SET AppropriationGroup = 'FEDERAL'
    WHERE APPN LIKE 'Federal%'
          AND PayPlan IN ( 'DB', 'DE', 'DJ', 'DK', 'GP', 'NH', 'NJ', 'NK' );

END;