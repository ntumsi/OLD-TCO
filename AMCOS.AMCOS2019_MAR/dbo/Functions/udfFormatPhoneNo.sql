
CREATE FUNCTION [dbo].[udfFormatPhoneNo] (@phone VARCHAR(20))  
  RETURNS VARCHAR(20)  -- Format phone number to (333)333-4444
AS  
BEGIN 
	DECLARE @pn VARCHAR(20)
	SET @pn = REPLACE(@phone, ' ','')
	SET @pn = REPLACE(@pn, '(','')
	SET @pn = REPLACE(@pn, ')','')
	SET @pn = REPLACE(@pn, '-','')
	SET @pn = REPLACE(@pn, '.','')
	IF LEN(@pn)=10 RETURN '(' + SUBSTRING(@pn,1,3) + ')' + SUBSTRING(@pn,4,3) + '-' + SUBSTRING(@pn,7,4)
	RETURN @phone
END