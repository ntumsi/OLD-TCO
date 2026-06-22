
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[UpdateArmyCesTitle]
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;


    UPDATE a
    SET a.ArmyCesTitle = b.ArmyCesTitle
    FROM lookup.CostElement a
        JOIN lookup.CostElement b
            ON b.PayPlan = 'RE'
               AND a.CostElementId = b.CostElementId
    WHERE a.PayPlan = 'NE';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.01/4.02/4.03 - NGPA - Crew, Maintenance (MTOE), & System-Specific Support'
    WHERE ArmyCesTitle = '4.01/4.02/4.03 - RPA - Crew, Maintenance (MTOE), & System-Specific Support'
          AND PayPlan = 'NE';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.051 - NGPA - Replacement Personnel (Training)'
    WHERE ArmyCesTitle = '4.051 - RPA - Replacement Personnel (Training)'
          AND PayPlan = 'NE';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.06 - NGPA - Other Military Personnel Costs'
    WHERE ArmyCesTitle = '4.06 - RPA - Other Military Personnel Costs'
          AND PayPlan = 'NE';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.11 - OMNG - Training'
    WHERE ArmyCesTitle = '5.11 - OMAR - Training'
          AND PayPlan = 'NE';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.12 - OMNG - Other'
    WHERE ArmyCesTitle = '5.12 - OMAR - Other'
          AND PayPlan = 'NE';


    UPDATE a
    SET a.ArmyCesTitle = b.ArmyCesTitle
    FROM lookup.CostElement a
        JOIN lookup.CostElement b
            ON b.PayPlan = 'RO'
               AND a.CostElementId = b.CostElementId
    WHERE a.PayPlan = 'NO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.01/4.02/4.03 - NGPA - Crew, Maintenance (MTOE), & System-Specific Support'
    WHERE ArmyCesTitle = '4.01/4.02/4.03 - RPA - Crew, Maintenance (MTOE), & System-Specific Support'
          AND PayPlan = 'NO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.051  - NGPA - Replacement Personnel (Training)'
    WHERE ArmyCesTitle = '4.051 - RPA - Replacement Personnel (Training)'
          AND PayPlan = 'NO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.06 - NGPA - Other Military Personnel Costs'
    WHERE ArmyCesTitle = '4.06 - RPA - Other Military Personnel Costs'
          AND PayPlan = 'NO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.11 - OMNG - Training'
    WHERE ArmyCesTitle = '5.11 - OMAR - Training'
          AND PayPlan = 'NO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.12 - OMNG - Other'
    WHERE ArmyCesTitle = '5.12 - OMAR - Other'
          AND PayPlan = 'NO';

    UPDATE a
    SET a.ArmyCesTitle = b.ArmyCesTitle
    FROM lookup.CostElement a
        JOIN lookup.CostElement b
            ON b.PayPlan = 'RWO'
               AND a.CostElementId = b.CostElementId
    WHERE a.PayPlan = 'NWO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.01/4.02/4.03 - NGPA - Crew, Maintenance (MTOE), & System-Specific Support'
    WHERE ArmyCesTitle = '4.01/4.02/4.03 - RPA - Crew, Maintenance (MTOE), & System-Specific Support'
          AND PayPlan = 'NWO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '4.051 - NGPA - Replacement Personnel (Training)'
    WHERE ArmyCesTitle = '4.051 - RPA - Replacement Personnel (Training)'
          AND PayPlan = 'NWO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.11 - OMNG - Training'
    WHERE ArmyCesTitle = '5.11 - OMAR - Training'
          AND PayPlan = 'NWO';

    UPDATE lookup.CostElement
    SET ArmyCesTitle = '5.12 - OMNG - Other'
    WHERE ArmyCesTitle = '5.12 - OMAR - Other'
          AND PayPlan = 'NWO';

END;