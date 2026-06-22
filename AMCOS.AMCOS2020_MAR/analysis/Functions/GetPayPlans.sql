
-- =============================================
-- Author:		Dan Hogan
-- Create date: 11/14/2020
-- Description:	This is a helper function so we can quickly get a set of pay plans based on a key word
-- for example rather than having to ask for 9 different pay plans and type them out for military, one could ask the function for military and it woudl return a table
-- with just the applicable pay plans 
-- because i find myself writing out the pay plans in so many cases i figured this helper would save time
-- =============================================
CREATE FUNCTION [analysis].[GetPayPlans]
(
    @PayPlanType NVARCHAR(50) = '-1'
)
RETURNS @PayPlans TABLE
(
    -- Add the column definitions for the TABLE variable here
    PayPlan NVARCHAR(3) NOT NULL
)
AS
BEGIN
    -- Fill the table variable with the rows for your result set

    --if an actual pay plan is passed then return a table of just that pay plan
    IF @PayPlanType IN
       (
           SELECT PayPlan FROM lookup.PayPlan
       )
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        (@PayPlanType);

    END;
    ELSE IF @PayPlanType = 'All'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        SELECT PayPlan
        FROM lookup.PayPlan;
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('SES'); --in the above the PayPlan official title is ES so we add SES here to be complete
    END;
    ELSE IF @PayPlanType = 'Military'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('AO'),
        ('AWO'),
        ('AE'),
        ('RE'),
        ('RO'),
        ('RWO'),
        ('NE'),
        ('NO'),
        ('NWO');

    END;
    ELSE IF @PayPlanType = 'Active'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('AO'),
        ('AWO'),
        ('AE');

    END;
    ELSE IF @PayPlanType = 'NG_R'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('RE'),
        ('RO'),
        ('RWO'),
        ('NE'),
        ('NO'),
        ('NWO');

    END;
    ELSE IF @PayPlanType = 'NG'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('NE'),
        ('NO'),
        ('NWO');

    END;
    ELSE IF @PayPlanType = 'Reserve'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('RE'),
        ('RO'),
        ('RWO');

    END;
    ELSE IF @PayPlanType = 'Officer'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('AO'),
        ('RO'),
        ('NO');
    END;
    ELSE IF @PayPlanType = 'Enlisted'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('AE'),
        ('RE'),
        ('NE');
    END;
    ELSE IF @PayPlanType = 'Warrant'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('AWO'),
        ('RWO'),
        ('NWO');
    END;
    ELSE IF @PayPlanType = 'GFEBS'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('NH'),
        ('NJ'),
        ('NK'),
        ('DB'),
        ('DE'),
        ('DJ'),
        ('DK'),
        ('GP');
    END;
    ELSE IF @PayPlanType = 'Acq'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('NH'),
        ('NJ'),
        ('NK');
    END;
    ELSE IF @PayPlanType = 'Lab Demo'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('DE'),
        ('DJ'),
        ('DK'),
        ('DB');

    END;
    ELSE IF @PayPlanType = 'G'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('GS'),
        ('GG'),
        ('GL'),
        ('GP');
    END;
	    ELSE IF @PayPlanType = 'OPM_G'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('GS'),
        ('GG'),
        ('GL');
      
    END;
    ELSE IF @PayPlanType = 'Wage'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        SELECT PayPlan
        FROM lookup.PayPlan
        WHERE PayPlan LIKE 'W%'
              OR PayPlan LIKE 'X%'
			  OR PayPlan IN ('NA','NL','NS')
    END;
    ELSE IF @PayPlanType = 'Civ'
    BEGIN
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        VALUES
        ('NH'),
        ('NJ'),
        ('NK'),
        ('DB'),
        ('DE'),
        ('DJ'),
        ('DK'),
        ('GP'),
        ('GS'),
        ('GG'),
        ('GL'),
        ('SES'),
        ('CCE');
        INSERT INTO @PayPlans
        (
            PayPlan
        )
        SELECT PayPlan
        FROM lookup.PayPlan
        WHERE PayPlan LIKE 'W%'
              OR PayPlan LIKE 'X%';
    END;
    RETURN;
END;