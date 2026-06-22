
		create FUNCTION webuser.[GetDateOnNthDayOfMonth]
(
    @intIteration int = null,
    @strDay varchar(9) = null,
    @dtToday datetime = null
)
RETURNS datetime
AS
BEGIN
    DECLARE @dtReturn datetime = NULL
    DECLARE @dtDate datetime
 
    SET @strDay = ISNULL(@strDay, 'Monday')
    SET @dtToday = ISNULL(@dtToday,GETDATE())
    SET @dtDate = @dtToday
    SET @intIteration = ISNULL(@intIteration,1) - 1
 
    WHILE @dtReturn IS NULL
        BEGIN
            IF DATENAME(WEEKDAY, @dtDate) = @strDay
                SET @dtReturn = DATEADD(DAY, @intIteration * 7, @dtDate)
            ELSE
                SET @dtDate = DATEADD(DAY, 1, @dtDate)
        END
 
    RETURN @dtReturn
END