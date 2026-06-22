
-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION crunch.AvgAnnualizedCostOfBasePayMilitary
(
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(4),
    @ActiveDutyDays TINYINT
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
    SELECT tblPay.GradeType,
           tblPay.GradeLevel,
           (tblPay.calPay / InventoryByGradeForCategorySubgroup.Amount) AS calAmount
    FROM
    (
        SELECT AnnualBasicPayReserveComponents.GradeType,
               AnnualBasicPayReserveComponents.GradeLevel,
               SUM(AnnualBasicPayReserveComponents.Amount * InventoryByGradeYosForCategorySubgroup.Amount) AS calPay
        FROM crunch.AnnualBasicPayReserveComponents(@PayPlan, @ActiveDutyDays) AnnualBasicPayReserveComponents
            INNER JOIN crunch.InventoryByGradeYosForCategorySubgroup(@PayPlan, @CategorySubgroupCode) InventoryByGradeYosForCategorySubgroup
                ON AnnualBasicPayReserveComponents.GradeType = InventoryByGradeYosForCategorySubgroup.GradeType
                   AND AnnualBasicPayReserveComponents.GradeLevel = InventoryByGradeYosForCategorySubgroup.GradeLevel
                   AND AnnualBasicPayReserveComponents.YOS = InventoryByGradeYosForCategorySubgroup.Step_YOS
        GROUP BY AnnualBasicPayReserveComponents.GradeType,
                 AnnualBasicPayReserveComponents.GradeLevel
    ) tblPay
        INNER JOIN crunch.InventoryByGradeForCategorySubgroup(@PayPlan, @CategorySubgroupCode) InventoryByGradeForCategorySubgroup
            ON InventoryByGradeForCategorySubgroup.GradeType = tblPay.GradeType
               AND InventoryByGradeForCategorySubgroup.GradeLevel = tblPay.GradeLevel;

    RETURN;
END;