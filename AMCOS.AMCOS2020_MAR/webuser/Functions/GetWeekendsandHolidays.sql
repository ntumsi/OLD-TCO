CREATE FUNCTION webuser.GetWeekendsandHolidays
(
 @start DATE,
 @end date
)
RETURNS @nonworkdays table
(
	
			mydate  date NOT NULL,
			mytype  NVARCHAR(50) NOT NULL,
			dow NVARCHAR(20) NOT NULL,
            newdate date NOT null
)
AS 
begin


		DECLARE @i DATE = @start
		WHILE @i<=@end
		BEGIN
			DECLARE @datename NVARCHAR(20)= DATENAME(WEEKDAY,@i)
			declare @weekofmonth int = datepart(day, datediff(day, 0, @i)/7 * 7)/7 + 1

			IF @datename  ='Sunday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Weekend',@datename,dateadd(DAY,1,@i))
			ELSE IF @datename  ='Saturday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Weekend',@datename,dateadd(DAY,2,@i))
			   
			--#######    New Years Day    ########
			IF MONTH(@i)=1 AND DAY(@i)=1 AND @datename = 'Saturday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,-1,@i),'New Years Day',@datename,dateadd(DAY,2,@i))
			ELSE IF MONTH(@i)=1 AND DAY(@i)=1 AND @datename = 'Sunday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,+1,@i),'New Years Day',@datename,dateadd(DAY,+2,@i))
			ELSE IF MONTH(@i)=1 AND DAY(@i)=1 AND @datename not IN  ('Sunday','Saturday')
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'New Years Day',@datename,dateadd(DAY,+1,@i))

			--#######    4th of July    ########
			ELSE IF MONTH(@i)=7 AND DAY(@i)=4 AND @datename = 'Saturday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,-1,@i),'4th of July',@datename,dateadd(DAY,2,@i))
			ELSE IF MONTH(@i)=7 AND DAY(@i)=4 AND @datename = 'Sunday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,+1,@i),'4th of July',@datename,dateadd(DAY,+2,@i))
			ELSE IF MONTH(@i)=7 AND DAY(@i)=4 AND @datename not IN  ('Sunday','Saturday')
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'4th of July',@datename,dateadd(DAY,+1,@i))

			--#######    Veterans Day (always Nov 11)    ########
			ELSE IF MONTH(@i)=11 AND DAY(@i)=11 AND @datename = 'Saturday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,-1,@i),'Veterans Day',@datename,dateadd(DAY,2,@i))
			ELSE IF MONTH(@i)=11 AND DAY(@i)=11 AND @datename = 'Sunday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,+1,@i),'Veterans Day',@datename,dateadd(DAY,+2,@i))
			ELSE IF MONTH(@i)=11 AND DAY(@i)=11 AND @datename not IN  ('Sunday','Saturday')
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Veterans Day',@datename,dateadd(DAY,+1,@i))				
								
			--#######    Christmas (always Dec 25)    ########
			ELSE IF MONTH(@i)=12 AND DAY(@i)=25 AND @datename = 'Saturday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,-1,@i),'Christmas Day',@datename,dateadd(DAY,2,@i))
			ELSE IF MONTH(@i)=12 AND DAY(@i)=25 AND @datename = 'Sunday'
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (DATEADD(DAY,+1,@i),'Christmas Day',@datename,dateadd(DAY,+2,@i))
			ELSE IF MONTH(@i)=12 AND DAY(@i)=25 AND @datename not IN  ('Sunday','Saturday')
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Christmas Day',@datename,dateadd(DAY,+1,@i))
				
			--#######    MLK Day (3rd Monday IN Jan)    ########			
			 ELSE IF MONTH(@I)=1 AND webuser.GetDateOnNthDayOfMonth(3,'Monday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'MLK Day',@datename,dateadd(DAY,+1,@i))			
			
			--#######    Presidents Day (3rd Monday IN Feb)    ########	
			 ELSE IF MONTH(@I)=2 AND webuser.GetDateOnNthDayOfMonth(3,'Monday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Presidents Day',@datename,dateadd(DAY,+1,@i))
						
			
			--#######    Columbus Day (2nd Mon in Oct)    ########			
			 ELSE IF MONTH(@I)=10 AND webuser.GetDateOnNthDayOfMonth(2,'Monday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Columbus Day',@datename,dateadd(DAY,+1,@i))	
						

			--#######    Labor Day (1st Monday in Sept)    ########		
			 ELSE IF MONTH(@I)=9 AND webuser.GetDateOnNthDayOfMonth(1,'Monday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Labor Day',@datename,dateadd(DAY,+1,@i))	
								
			
			--#######    Thanksgiving Day (4th Thursday in Nov)    ########	
			 ELSE IF MONTH(@I)=11 AND webuser.GetDateOnNthDayOfMonth(4,'Thursday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Thanksgiving Day',@datename,dateadd(DAY,+1,@i))	
					
			--#######    Memorial Day (Last Monday in May)    ########	
			 ELSE IF MONTH(@I)=5 AND webuser.GetDateOnNthDayOfMonth(4,'Monday',DATEFROMPARTS(YEAR(@i),MONTH(@i),1))=@i
				INSERT INTO @nonworkdays (mydate,mytype,dow,newdate) VALUES (@i,'Memorial Day',@datename,dateadd(DAY,+1,@i))		
								
			SET @i = DATEADD(DAY,+1,@i)

		END
		return
 end