-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE  PROCEDURE [analysis].[MAD]
	-- Add the parameters for the stored procedure here
	
	@amcosversionid int = -1,
	@payplans NVARCHAR(50) = '-1'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



	--even though amcosversionid are an int we need them as a string to work with the dynamic sql
	--rather than cast everywhere we use the variable let's just make this adjustment once and use it
	--we could have made the parameters be strings but that might be confusing since the DB everywhere uses them as an int
	--so let the SP do the work
	declare @version  nvarchar(6)
	set @version = cast(	@amcosversionid as nvarchar(6) )
	

	declare @detailsql as nvarchar(max) = '

	
 SELECT 
 case
 WHEN MeanAD > 50000 THEN ''1 >50k''
 WHEN MeanAD > 25000 THEN ''2 >25k'' 
 WHEN MeanAD > 10000 THEN ''3 >10k'' 
 WHEN MeanAD >  5000 THEN ''4 >5k''
 WHEN MeanAD >  1000 THEN ''5 >1k''
  WHEN MeanAD < 1000 THEN ''6 <1k''  
  END AS MeanAD_Bin
 , 
  case
 WHEN MedianAD > 50000 THEN ''1 >50k''
 WHEN MedianAD > 25000 THEN ''2 >25k''
 WHEN MedianAD > 10000 THEN ''3 >10k'' 
 WHEN MedianAD >  5000 THEN ''4 >5k'' 
 WHEN MedianAD >  1000 THEN ''5 >1k''
  WHEN MedianAD < 1000 THEN ''6 <1k''  
  END AS MedianAD_Bin
 , 
 format(costs,''$###,####,####'') as costs,format(ppStrlMedian,''$###,####,####'') as ppStrlMedian, format(ppStrlMean,''$###,####,####'') as ppStrlMean,format(MedianAD,''$###,####,####'') as MedianAD , format(MeanAD,''$###,####,####'') as MeanAD,  payplan, CategoryGroupCode, categorygroupdescription,CategorySubgroupCode, categorysubgroupdescription, locationid, location_name,strl, gradetype, gradelevel, DependencyStatus, amcosversionid
 FROM 
 (
SELECT  costs,ppStrlMedian,ppStrlMean,ABS(costs-ppStrlMedian) AS MedianAD , ABS(costs-ppStrlMean) AS MeanAD,  payplan, CategoryGroupCode, categorygroupdescription,CategorySubgroupCode, categorysubgroupdescription, locationid, location_name,strl, gradetype, gradelevel, DependencyStatus, amcosversionid

FROM (
SELECT  payplan, CategoryGroupCode, categorygroupdescription,CategorySubgroupCode, categorysubgroupdescription, locationid, location_name,strl, gradetype, gradelevel, DependencyStatus, amcosversionid, costs,
PERCENTILE_DISC(.5) within GROUP (order BY costs) 
OVER (PARTITION BY payplan, strl, locationid,gradetype, gradelevel, DependencyStatus, amcosversionid)
AS ppStrlMedian, AVG(costs) OVER (partition BY payplan, strl, locationid,gradetype, gradelevel, DependencyStatus, amcosversionid) AS ppStrlMean
FROM (
 SELECT payplan, CategoryGroupCode, categorygroupdescription,CategorySubgroupCode, categorysubgroupdescription, locationid, location_name,strl, gradetype, gradelevel, DependencyStatus, amcosversionid,CAST(SUM(amount) AS NUMERIC(16,2)) AS costs
  FROM data.costswithdescriptions WHERE costelementid IN (SELECT costelementid FROM lookup.costsummaryelement AS a 
 INNER JOIN lookup.costsummary AS b ON a.SummaryId = b.SummaryId WHERE name=''Default'')
 and amcosversionid=' + @version + ' 
 and payplan in (SELECT payplan FROM analysis.getpayplans('''+@payplans+'''))
 AND categorysubgroupcode<>''-1'' 
 and careerprogramnumber=''-1''
 --AND payplan NOT IN (''AE'',''AO'',''AWO'') -- active 
 and  locationid = case when payplan in (''AE'',''AO'',''AWO'') then -1 else locationid end 
 GROUP BY payplan, CategoryGroupCode, categorygroupdescription,CategorySubgroupCode, categorysubgroupdescription, locationid, location_name,strl, gradetype, gradelevel, DependencyStatus, amcosversionid
 ) AS a
 ) AS a
 ) AS a ORDER BY MeanAD_Bin asc


	'
	
	
	
	--summary
	SELECT 'MeanAD Summary'
	declare @MeanADSummary as nvarchar(max) = '
	with CTE as (
	select payplan, [1 >50k],[2 >25k],[3 >10k],[4 >5k],[5 >1k],[6 <1k]
	
	from ( ' + @detailsql + ' ) as a pivot ( count(costs) for meanad_bin in ([1 >50k],[2 >25k],[3 >10k],[4 >5k],[5 >1k],[6 <1k])
	) as pvt
	)
	select payplan, sum([1 >50k]) as [1 >50k],sum([2 >25k]) as [2 >25k],sum([3 >10k]) as [3 >10k],sum([4 >5k]) as [4 >5k],sum([5 >1k]) as [5 >1k],sum([6 <1k]) as [6 <1k]
	from CTE
	group by payplan
	order by payplan
	'
	SET @MeanADSummary= REPLACE(@MeanADSummary, 'ORDER BY MeanAD_Bin asc','')
	PRINT @MeanADSummary
	exec sys.sp_executesql @MeanADSummary
	

	
	----series level changes
	--declare @seriessql as nvarchar(max)
	--set @seriessql = replace(@detailsql,'strl,country,wagearea,wageschedule,mha,opm_location,','')
	

	----group level changes
	--declare @groupsql as nvarchar(max)
	--set @groupsql = replace(@seriessql,'categorysubgroupcode,','')
	
	----pp,gl level changes
	--declare @glsql as nvarchar(max)
	--set @glsql = replace(@groupsql,'categorygroupcode,','')

	----pp level changes
	--declare @ppsql as nvarchar(max)
	--set @ppsql = replace(@glsql,'gradetype,gradelevel,','')

	--select 'pp level changes'
	--exec sys.sp_executesql @ppsql

	--select 'GL level changes'
	--exec sys.sp_executesql @glsql

	--select 'group level changes'
	--exec sys.sp_executesql @groupsql

	--select 'series, and grade level changes'
	--exec sys.sp_executesql @seriessql

	select 'series, location, and grade level changes'
	exec sys.sp_executesql @detailsql


	--EXEC analysis.MAD @amcosversionid=202001, @payplans='GFEBS'
END