-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[PayPlanXWalk]
    (
        @PayPlan NVARCHAR(3) ,
        @CategorySubGroupCode NVARCHAR(4) ,
        @GradeLevel TINYINT
    )
RETURNS TABLE
AS
    RETURN (   SELECT ( SELECT SUM(Amount)
                        FROM   data.Costs c
                        WHERE  c.PayPlan = @PayPlan
                               AND CategorySubGroupCode = @CategorySubGroupCode
                               AND GradeLevel = @GradeLevel
                               AND CostElementName = 'Avg Cost of Premium Pay'
                      ) AS lblV_PremiumPay ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Federal Employees Gov''t Health Insurance'
                      ) AS lblV_Health ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Federal Employees Gov''t Life Insurance'
                      ) AS lblV_Life ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Miscellaneous Pay'
                      ) AS lblV_MiscPay ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Training'
                      ) AS lblV_wTraining ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Army-Funded Retirement'
                      ) AS lblV_aRetirement ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Cash Awards'
                      ) AS lblV_wCashAward ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Annualized Cost of FICA'
                      ) AS lblV_wFICA ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Former Employee Compensation'
                      ) AS lblV_wFormerEmpComp ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Post Retirement Health Insurance'
                      ) AS lblV_HealthPost ,
                      (   SELECT SUM(Amount)
                          FROM   data.Costs c
                          WHERE  c.PayPlan = @PayPlan
                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                 AND GradeLevel = @GradeLevel
                                 AND CostElementName = 'Avg Cost of Post Retirement Life Insurance'
                      ) AS lblV_LifePost
           );