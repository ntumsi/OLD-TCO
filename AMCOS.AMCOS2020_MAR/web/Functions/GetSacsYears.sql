-- =============================================
-- Author:		Name
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [web].[GetSacsYears]
(
    @UIC NVARCHAR(6),
    @UnitLocation NVARCHAR(150),
    @NotSelectedPayPlans NVARCHAR(500),
    @MtoeProjectInventoryYear NVARCHAR(25) = NULL
)
RETURNS TABLE
AS
RETURN SELECT UIC,
              AuthorizationDocument,
              UICTitle,
              PayPlan,
              CategoryGroupCode,
              CategorySubgroupCode,
              CASE @UnitLocation
                  WHEN 'unchanged' THEN
                      LocationId
                  WHEN 'national' THEN
                      -1
                  ELSE
                      -1
              END LocationId,
              CASE @UnitLocation
                  WHEN 'unchanged' THEN
                      LocationText
                  ELSE
                      LocationText
              END LocationText,
              STRL,
              GradeLevel,
              DependentStatus,
              NumberOfDependents,
              ActiveDutyDays,
              Inventory,
              UnitYear
       FROM warehouse.UnitPersonnel
       WHERE UIC = @UIC
             AND UnitYear <> 'OTOE'
             AND
             (
                 @MtoeProjectInventoryYear IS NULL
                 OR UnitYear = @MtoeProjectInventoryYear
             )
             AND PayPlan NOT IN
                 (
                     SELECT value FROM STRING_SPLIT(@NotSelectedPayPlans, ',')
                 );