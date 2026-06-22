






CREATE VIEW [quicksight].[PPXwalkPayPlanSubgroup] AS
  SELECT DISTINCT CategorySubgroupCode,CategorySubgroupDescription, a.CategorySubgroupCode + ' - ' + a.CategorySubgroupDescription  AS DisplaySubgroup 
  FROM data.CategorySubgroup AS a
  
 INNER JOIN
  
  
  
	(
		--no point in allowing in a subgroup which doesn't itself have a cross walk
		--non cce
		
		SELECT  DISTINCT   TargetSubgroupCode AS subgroupcode  FROM warehouse.PPXwalk 
		
	) AS b ON  a.CategorySubgroupCode=b.subgroupcode
	-- !!! FOR DEV PURPOSES ONLY TO REDUCE DATA SIZE, REMOVE THIS FOR FINAL TESTING
	--where CategorySubgroupCode='1515'