



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
--EXEC analysis.CompareCosts 202201,202301, 'Default',1,'All'
CREATE  PROCEDURE [analysis].[CompareCosts]
	-- Add the parameters for the stored procedure here
	
	@amcosversionidprior INT = -1,
	@amcosversionidnew INT = -1,
	@Summary NVARCHAR(20) = '-1',
	@SumToGradeLevelTotal BIT = 0,
	@PayPlanorPayPlanType NVARCHAR(50) = '-1'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--even though amcosversionid are an int we need them as a string to work with the dynamic sql
	--rather than cast everywhere we use the variable let's just make this adjustment once and use it
	--we could have made the parameters be strings but that might be confusing since the DB everywhere uses them as an int
	--so let the SP do the work
	declare @IDprior  nvarchar(6), @IDnew nvarchar(6)
	set @IDprior = cast(@amcosversionidprior as nvarchar(6) )
	set @IDnew = cast(@amcosversionidnew as nvarchar(6) )


	
declare @detailsql as nvarchar(max) = '
	select * from (
		SELECT 
		format(abs([' + @IDprior + '] -  [' + @IDnew + ']),''$###,####,####'') as ''delta'',
		format([' + @IDprior + '],''$###,####,####'')  as prioramt,
		format([' + @IDnew + '],''$###,####,####'')  as newamt,
		case 
		

		when  [' + @IDprior + '] =0  and  [' + @IDnew + '] > 0 then ''1 rose from zero''
		when  [' + @IDnew + '] =0  and  [' + @IDprior + '] > 0 then ''2 went to zero''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >100000 then ''3 over 100,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >75000 then ''4 over 75,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >50000 then ''5 over 50,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >25000 then ''6 over 25,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >10000 then ''7 over 10,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >5000 then ''8 over 5,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >1000 then ''9a over 1,000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >500 then ''9b over 500''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >50 then ''9c over 50''

		

		else   ''9d very small''
 
		end as amt_bin 
		,*
		FROM
		(

	select payplan,CategoryGroupCode,CategorySubgroupCode,strl,locationid,
		careerprogramnumber,DependentStatus,Numberofdependents,costelementid,gradelevel,weaponsystemid,weaponsystemname,
		costelementcategory,costelementname,appn, 
	isnull([' + @IDprior +'],0) as [' + @IDprior + '], 
	isnull(['+ @IDnew +'],0) as [' + @IDnew + ']
	from
	(

		select payplan,CategoryGroupCode,CategorySubgroupCode,strl,locationid,
		careerprogramnumber,DependentStatus,Numberofdependents,costelementid,gradelevel,a.weaponsystemid,b.weaponsystemname,
		costelementcategory,costelementname,appn, amcosversionid, sum(amount) as costs
		from data.costs as a left outer join lookup.weaponsystem as b on a.weaponsystemid=b.weaponsystemid
		where  costelementid in 
		(
			select costelementid from lookup.CostSummaryElement as a 
			inner join lookup.CostSummary as b on a.summaryid=b.summaryid
			where b.Name=''Default'' 
			--and payplan in (select payplan from analysis.getpayplans (''' + @PayPlanorPayPlanType + '''))
		)
		and locationid=-1 and categorysubgroupcode<>''-1''
		and ' + @IDnew + ' between b.[AmcosVersionIdStart] and b.[AmcosVersionIdend]
      
		group by payplan,CategoryGroupCode,CategorySubgroupCode,strl,locationid,
		careerprogramnumber,DependentStatus,Numberofdependents,costelementid,gradelevel,a.weaponsystemid,weaponsystemname,
		costelementcategory,costelementname,appn, gradelevel, amcosversionid

	) as a
	pivot
	(
		sum(costs)
		for amcosversionid  IN ([' + @IDprior+'], [' + @IDnew + '])
	) as pvt
	
	
	) as a
	) as a
	order by amt_bin asc, delta desc
	'


	--process the passed in summary name filter
	IF @Summary IN (SELECT Name FROM lookup.CostSummary)
	BEGIN
		SET @detailsql = REPLACE (@detailsql,'DEFAULT',@Summary )
	END
	ELSE
	BEGIN
	 RAISERROR('INVALID summary name',18,1)
	 return
	END 



	DECLARE @ppsummary AS nvarchar(MAX)
	SET @ppsummary = REPLACE(@detailsql,'order by amt_bin asc, delta desc','')
	SET @ppsummary = 
	'
	with CTE as (
	select payplan, [1 rose from zero],[2 went to zero],[3 over 100,000],[4 over 75,000],[5 over 50,000],[6 over 25,000],[7 over 10,000],[8 over 5,000],[9a over 1,000],[9b over 500],[9c over 50], [9d very small]
	
	from ( ' + @ppsummary + ' ) as a pivot ( count(amt_bin) for amt_bin in ([1 rose from zero],[2 went to zero],[3 over 100,000],[4 over 75,000],[5 over 50,000],[6 over 25,000],[7 over 10,000],[8 over 5,000],[9a over 1,000],[9b over 500],[9c over 50], [9d very small])
	) as pvt
	)
	select payplan, sum([1 rose from zero]) as [1 rose from zero],sum([2 went to zero]) as [2 went to zero],sum([3 over 100,000]) as [3 over 100,000],
	sum([4 over 75,000]) as [4 over 75,000],sum([5 over 50,000]) as [5 over 50,000] ,sum([6 over 25,000]) as [6 over 25,000],sum([7 over 10,000]) as [7 over 10,000] ,sum([8 over 5,000]) as [8 over 5,000], sum([9a over 1,000]) as [9a over 1,000], sum([9b over 500]) as [9b over 500],sum([9c over 50]) as [9c over 50], sum([9d very small]) as [9d very small]
	from CTE
	group by payplan
	order by payplan
	'
	PRINT @ppsummary
	SELECT 'pp summary'
	exec sys.sp_executesql @ppsummary

	DECLARE @cesummary AS nvarchar(MAX)
	SET @cesummary = REPLACE(@detailsql,'order by amt_bin asc, delta desc','')
	SET @cesummary = 
	'
	with CTE as (
	select payplan,costelementcategory,costelementname,weaponsystemname, [1 rose from zero],[2 went to zero],[3 over 100,000],[4 over 75,000],[5 over 50,000],[6 over 25,000],[7 over 10,000],[8 over 5,000],[9a over 1,000],[9b over 500],[9c over 50], [9d very small]
	
	from ( ' + @cesummary + ' ) as a pivot ( count(amt_bin) for amt_bin in ([1 rose from zero],[2 went to zero],[3 over 100,000],[4 over 75,000],[5 over 50,000],[6 over 25,000],[7 over 10,000],[8 over 5,000],[9a over 1,000],[9b over 500],[9c over 50], [9d very small])
	) as pvt
	)
	select payplan, costelementcategory,costelementname,weaponsystemname, sum([1 rose from zero]) as [1 rose from zero],sum([2 went to zero]) as [2 went to zero],sum([3 over 100,000]) as [3 over 100,000],
	sum([4 over 75,000]) as [4 over 75,000],sum([5 over 50,000]) as [5 over 50,000] ,sum([6 over 25,000]) as [6 over 25,000],sum([7 over 10,000]) as [7 over 10,000] ,sum([8 over 5,000]) as [8 over 5,000], sum([9a over 1,000]) as [9a over 1,000], sum([9b over 500]) as [9b over 500],sum([9c over 50]) as [9c over 50], sum([9d very small]) as [9d very small]
	from CTE
	group by payplan,costelementcategory,costelementname,weaponsystemname
	order by costelementcategory,costelementname,payplan
	'
	PRINT @cesummary
	SELECT 'cost element summary'
	exec sys.sp_executesql @cesummary

	--Career Program level changes
	DECLARE @CPsql AS NVARCHAR(MAX)
	SET @CPsql = REPLACE(@detailsql,'locationid,','')

	--group level changes
	DECLARE @groupsql AS NVARCHAR(MAX)
	SET @groupsql = REPLACE(@CPsql,'CategorySubgroupCode,strl,','')
	SET @groupsql = REPLACE(@groupsql,' and isnull(careerprogramnumber,''-1'')<>-1',' and isnull(CategorySubgroupCode,''0'') =''-1'' and CategoryGroupCode<>''-1'' ')
	SET @groupsql = REPLACE(@groupsql,'careerprogramnumber,','')

	--payplan level changes
	DECLARE @ppsql AS NVARCHAR(MAX)
	SET @ppsql = REPLACE(@groupsql,'CategoryGroupCode,','')
	SET @groupsql = REPLACE(@ppsql,' and isnull(CategorySubgroupCode,''0'') =''-1'' and CategoryGroupCode<>''-1'' ',' and categorygroupcode=''-1'' ')


		--process the sum to grade level
	--this removes costelement level of detail for easier high level review
	--if the value is 0 the query is already setup for that so do nothing (no else needed)
	IF @SumToGradeLevelTotal = 1
	BEGIN
		SET @detailsql = REPLACE (@detailsql,'costelementid,','')
				SET @detailsql = REPLACE (@detailsql,'a.weaponsystemid,','')
		SET @detailsql = REPLACE (@detailsql,'b.weaponsystemname,','')
		SET @detailsql = REPLACE (@detailsql,'weaponsystemid,','')
		SET @detailsql = REPLACE (@detailsql,'weaponsystemname,','')
		SET @detailsql = REPLACE (@detailsql,'costelementcategory,costelementname,appn,','')
	END


	--SELECT 'payplan average changes'
	--EXEC sys.sp_executesql @ppsql


	--SELECT 'group level changes'
	--EXEC sys.sp_executesql @groupsql


	--SELECT 'Career program costs'
	--EXEC sys.sp_executesql @CPsql
	
	SELECT 'location specific compare for bin 6 and greater'
	SET @detailsql = REPLACE(@detailsql,'order by amt_bin asc, delta desc','where amt_bin not like ''7%'' and amt_bin not like ''8%'' and amt_bin not like ''9%'' order by amt_bin asc, delta desc')
	PRINT @detailsql
	exec sys.sp_executesql @detailsql

	--EXEC analysis.CompareCosts 201901,202001, 'Default',1,'All'
	
END