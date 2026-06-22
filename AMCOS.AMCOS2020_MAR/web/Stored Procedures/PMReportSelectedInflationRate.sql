

CREATE PROCEDURE [web].[PMReportSelectedInflationRate]
    (
      @ProjectID INT ,
      @PayPlans VARCHAR(800)
    )
AS
    DECLARE @sql VARCHAR(2000);
--select cc.[Year], cc.CivPay, cc.OMA as ''OMA-CIV''  , cc.DoD_OMA as ''OMDW'', cc.FED_OMA as ''FED-OM''
--		, aa.MPA,			     aa.MPA_NonPay as ''MPA NonPay''    , aa.OMA as ''OMA-MIL'',  aa.DoD_OMA as ''OMDW'', aa.FED_OMA as ''FED-OMA1''
--		, nn.MPA as ''PA-NG'',  nn.OMA as ''OM-NG'' 
--		, rr.MPA as ''PA-RES'', rr.OMA as ''OM-RES'' 
--		, aa.OMA as ''OMA-CCE'' 
    SET @sql = '
select cc.[Year], cc.CivPay, cc.OMA as ''OMA-CIV''  , cc.DoD_OMA as ''OMDW'', cc.FED_OMA as ''FED-OM''
		, aa.MPA,			     aa.MPA_NonPay as ''MPA NonPay''    , aa.OMA as ''OMA-MIL'',  aa.DoD_OMA as ''OMDW'', aa.FED_OMA as ''FED-OM''
		, nn.MPA as ''NGPA'',  nn.OMA as ''OMNG'' 
		, rr.MPA as ''RPA'', rr.OMA as ''OMAR'' 
		, aa.OMA as ''OMA-CCE'' 
FROM (SELECT [Year], CivPay,          OMA, DoD_OMA, FED_OMA from lookup.InflationRates where [Type] = ''CIV'' ) cc
join (SELECT [Year], MPA, MPA_NonPay, OMA, DoD_OMA, FED_OMA from lookup.InflationRates where [Type] = ''MIL_A'') aa on cc.[Year]=aa.[Year]
join (SELECT [Year], MPA, OMA from lookup.InflationRates where [Type] = ''MIL_N'') nn on cc.[Year]=nn.[Year]
join (SELECT [Year], MPA, OMA from lookup.InflationRates where [Type] = ''MIL_R'') rr on cc.[Year]=rr.[Year]

where cc.[Year] between 
	   (select MIN(i.[Year] + p.YearStart)
		  FROM webuser.PMCategory c 
		  JOIN webuser.PMCategorySkill s ON c.UserID = s.UserID AND c.ProjectID = s.ProjectID AND c.CategoryID = s.CategoryID 
		  join webuser.PMProject p on c.ProjectID = p.ProjectID 
		  JOIN webuser.PMCategorySkillInventory i ON s.SkillID = i.SkillID 
		 WHERE i.[Year] < p.YearDuration and c.ProjectID = '
        + CONVERT(VARCHAR, @ProjectID) + ' and PayPlan in (' + @PayPlans
        + ') )  
	and
	   (select MAX(i.[Year] + p.YearStart)
		  FROM webuser.PMCategory c 
		  JOIN webuser.PMCategorySkill s ON c.UserID = s.UserID AND c.ProjectID = s.ProjectID AND c.CategoryID = s.CategoryID 
		  join webuser.PMProject p on c.ProjectID = p.ProjectID 
		  JOIN webuser.PMCategorySkillInventory i ON s.SkillID = i.SkillID 
		 WHERE i.[Year] < p.YearDuration and c.ProjectID = '
        + CONVERT(VARCHAR, @ProjectID) + ' and PayPlan in (' + @PayPlans
        + ') )  
order by cc.[Year]';
    EXEC(@sql);