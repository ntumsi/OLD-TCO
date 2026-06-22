

-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [crunch].[AvgCostOfBasePayMilitary]
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(4)
)
RETURNS @Table_Var TABLE
(
    GradeType NVARCHAR(3) NOT NULL,
    GradeLevel TINYINT NOT NULL,
    Amount NUMERIC(18, 2) NULL
)
AS
BEGIN
    INSERT INTO @Table_Var
    (
        GradeType,
        GradeLevel,
        Amount
    )
    SELECT GradeType,
           GradeLevel,
           SUM(AnnualBasicPay.Inventory * AnnualBasicPay.BasicPay) / SUM(AnnualBasicPay.Inventory) AS Amount
    FROM
    (
        SELECT AnnualBasicPay.GradeType,
               AnnualBasicPay.GradeLevel,
               AnnualBasicPay.YOS,
               InventoryByGrade.Amount AS Inventory,
               AnnualBasicPay.Amount AS BasicPay
        FROM crunch.AnnualBasicPayActiveDuty(@PayPlan) AnnualBasicPay
            INNER JOIN crunch.InventoryByGradeYosForCategorySubgroup(@PayPlan, @CategorySubgroupCode) InventoryByGrade
                ON AnnualBasicPay.GradeType = InventoryByGrade.GradeType
                   AND AnnualBasicPay.GradeLevel = InventoryByGrade.GradeLevel
                   AND AnnualBasicPay.YOS = InventoryByGrade.Step_YOS
    ) AnnualBasicPay
    GROUP BY GradeType,
             GradeLevel;

    RETURN;
END;