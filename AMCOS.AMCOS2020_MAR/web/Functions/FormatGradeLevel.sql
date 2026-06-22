-- =============================================
-- Author:      Name
-- Create Date: 
-- Description: 
-- =============================================
CREATE FUNCTION [web].[FormatGradeLevel]
(
    @PayPlan NVARCHAR(3),
    @GradeLevel TINYINT
)
RETURNS NVARCHAR(10)
AS
BEGIN
    DECLARE @Result NVARCHAR(10);
    DECLARE @GradeType NVARCHAR(3);

    SELECT @GradeType = CASE @PayPlan
                            WHEN 'AE' THEN
                                'E'
                            WHEN 'AO' THEN
                                'O'
                            WHEN 'AWO' THEN
                                'W'
                            WHEN 'NE' THEN
                                'E'
                            WHEN 'NO' THEN
                                'O'
                            WHEN 'NWO' THEN
                                'W'
                            WHEN 'RE' THEN
                                'E'
                            WHEN 'RO' THEN
                                'O'
                            WHEN 'RWO' THEN
                                'W'
                            ELSE
                                @PayPlan
                        END;
    SELECT @Result = CONCAT(@GradeType, @GradeLevel);
    RETURN @Result;
END;