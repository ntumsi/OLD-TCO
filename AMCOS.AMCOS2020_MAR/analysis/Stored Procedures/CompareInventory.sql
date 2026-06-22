-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE  PROCEDURE [analysis].[CompareInventory]
	-- Add the parameters for the stored procedure here
	
	@amcosversionidprior int = -1,
	@amcosversionidnew int = -1,
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
	declare @IDprior  nvarchar(6), @IDnew nvarchar(6)
	set @IDprior = cast(@amcosversionidprior as nvarchar(6) )
	set @IDnew = cast(@amcosversionidnew as nvarchar(6) )



	declare @detailsql as nvarchar(max) = '
	
		SELECT *,
		[' +@IDnew  + '] -  [' + @IDprior + '] as ''delta'',
		case 
		

		when  [' + @IDprior + '] =0  and  [' + @IDnew + '] > 0 then ''1 rose from zero''
		when  [' + @IDnew + '] =0  and  [' + @IDprior + '] > 0 then ''2 went to zero''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >1000 then ''3 over 1000''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >500 then ''4 over 500''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >100 then ''5 over 100''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >50 then ''6 over 50''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >25 then ''7 over 25''
		when  abs([' + @IDprior + '] -  [' + @IDnew + ']) >10 then ''8 over 10''

		

		else   ''9 very small''
 
		end as amt_bin 
		FROM
		(

	select payplan,categorysubgroupcode,categorygroupcode,strl,country,wagearea,wageschedule,mha,opm_location,gradetype,gradelevel, 
	isnull([' + @IDprior +'],0) as [' + @IDprior + '], 
	isnull(['+ @IDnew +'],0) as [' + @IDnew + ']
	from
	(
		SELECT payplan,categorysubgroupcode,categorygroupcode,strl,country,wagearea,wageschedule,mha,opm_location,gradetype,gradelevel,amcosversionid, sum (inventory) as inventory 
		FROM data.inventory WHERE amcosversionid IN (' + @IDprior +', ' + @IDnew + ') and payplan in (SELECT payplan FROM analysis.getpayplans(''' + @payplans + ''')) 
		group by payplan,categorysubgroupcode,categorygroupcode,strl,country,wagearea,wageschedule,mha,opm_location,gradetype,gradelevel,amcosversionid
	) as a
	pivot
	(
		sum(inventory)
		for amcosversionid  IN ([' + @IDprior+'], [' + @IDnew + '])
	) as pvt
	
	
	) as a
	order by amt_bin asc, abs([' +@IDnew  + '] -  [' + @IDprior + ']) desc
	'
	
	
	--series level changes
	declare @seriessql as nvarchar(max)
	set @seriessql = replace(@detailsql,'strl,country,wagearea,wageschedule,mha,opm_location,','')
	

	--group level changes
	declare @groupsql as nvarchar(max)
	set @groupsql = replace(@seriessql,'categorysubgroupcode,','')
	
	--pp,gl level changes
	declare @glsql as nvarchar(max)
	set @glsql = replace(@groupsql,'categorygroupcode,','')

	--pp level changes
	declare @ppsql as nvarchar(max)
	set @ppsql = replace(@glsql,'gradetype,gradelevel,','')

	select 'pp level changes'
	exec sys.sp_executesql @ppsql

	select 'GL level changes'
	exec sys.sp_executesql @glsql

	select 'group level changes'
	exec sys.sp_executesql @groupsql

	select 'series, and grade level changes'
	exec sys.sp_executesql @seriessql

	select 'series, location, and grade level changes'
	exec sys.sp_executesql @detailsql


	--EXEC analysis.compareinventory 201901,202001
END