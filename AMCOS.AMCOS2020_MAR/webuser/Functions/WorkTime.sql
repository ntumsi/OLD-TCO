CREATE FUNCTION [webuser].[WorkTime]
(
    @StartDate DATETIME,
    @FinishDate DATETIME
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @Temp BIGINT
    SET @Temp=0
 
    DECLARE @FirstDay DATE
    SET @FirstDay = CONVERT(DATE, @StartDate, 112)
 
    DECLARE @LastDay DATE
    SET @LastDay = CONVERT(DATE, @FinishDate, 112)
 
    DECLARE @StartTime TIME
    SET @StartTime = CONVERT(TIME, @StartDate)
 
    DECLARE @FinishTime TIME
    SET @FinishTime = CONVERT(TIME, @FinishDate)
 
    DECLARE @WorkStart TIME
    SET @WorkStart = '08:00'
 
    DECLARE @WorkFinish TIME
    SET @WorkFinish = '17:00'
 
    DECLARE @DailyWorkTime BIGINT
    SET @DailyWorkTime = DATEDIFF(MINUTE, @WorkStart, @WorkFinish)
 
    IF (@StartTime<@WorkStart)
    BEGIN
        SET @StartTime = @WorkStart
    END
    IF (@FinishTime>@WorkFinish)
    BEGIN
        SET @FinishTime=@WorkFinish
    END
    IF (@FinishTime<@WorkStart)
    BEGIN
        SET @FinishTime=@WorkStart
    END
    IF (@StartTime>@WorkFinish)
    BEGIN
        SET @StartTime = @WorkFinish
    END
 
    DECLARE @CurrentDate DATE
    SET @CurrentDate = @FirstDay
    DECLARE @LastDate DATE
    SET @LastDate = @LastDay
 
    WHILE(@CurrentDate<=@LastDate)
    BEGIN      
        IF @CurrentDate NOT IN (SELECT mydate FROM webuser.GetWeekendsandHolidays(@CurrentDate,@lastdate))
        BEGIN
            IF (@CurrentDate!=@FirstDay) AND (@CurrentDate!=@LastDay)
            BEGIN
                SET @Temp = @Temp + @DailyWorkTime
            END
            --IF it starts at startdate and it finishes not this date find diff between work finish and start as minutes
            ELSE IF (@CurrentDate=@FirstDay) AND (@CurrentDate!=@LastDay)
            BEGIN
                SET @Temp = @Temp + DATEDIFF(MINUTE, @StartTime, @WorkFinish)
            END
 
            ELSE IF (@CurrentDate!=@FirstDay) AND (@CurrentDate=@LastDay)
            BEGIN
                SET @Temp = @Temp + DATEDIFF(MINUTE, @WorkStart, @FinishTime)
            END
            --IF it starts and finishes in the same date
            ELSE IF (@CurrentDate=@FirstDay) AND (@CurrentDate=@LastDay)
            BEGIN
                SET @Temp = DATEDIFF(MINUTE, @StartTime, @FinishTime)
            END
        END
        SET @CurrentDate = DATEADD(day, 1, @CurrentDate)
    END
 
    -- Return the result of the function
    IF @Temp<0
    BEGIN
        SET @Temp=0
    END
    RETURN @Temp
 
END