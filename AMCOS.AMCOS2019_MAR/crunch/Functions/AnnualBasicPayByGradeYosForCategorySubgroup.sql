

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[AnnualBasicPayByGradeYosForCategorySubgroup]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(4)
)
RETURNS TABLE
AS
RETURN
(
    SELECT AnnualBasicPay.GradeType,
           AnnualBasicPay.GradeLevel,
           AnnualBasicPay.YOS,
           AnnualBasicPay.Amount
    FROM crunch.AnnualBasicPayActiveDuty(@PayPlan) AnnualBasicPay
        INNER JOIN crunch.InventoryByGradeYosForCategorySubgroup(@PayPlan, @CategorySubgroupCode) Inventory
            ON AnnualBasicPay.GradeType = Inventory.GradeType
               AND AnnualBasicPay.GradeLevel = Inventory.GradeLevel
               AND AnnualBasicPay.YOS = Inventory.Step_YOS
);