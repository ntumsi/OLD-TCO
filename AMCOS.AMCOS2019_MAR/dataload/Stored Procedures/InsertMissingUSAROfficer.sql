CREATE PROCEDURE [dataload].[InsertMissingUSAROfficer]
AS
BEGIN
    INSERT INTO load_inventory.Inventory_Military_Officer
    (
        PayPlan,
        BranchFA,
        AOC,
        Quality,
        GradeType,
        GradeLevel,
        YOS,
        Inventory
    )
    VALUES
    (N'RO', N'00', N'00B', 1, N'O', 9, 41, 1);
END;