


/****** Script for SelectTopNRows command from SSMS  ******/
CREATE view [analysis].[PythonMILInventoryViz] as 
select * , Inventory-priorinv as delta, abs(Inventory-priorinv) as absdelta from 
(
SELECT *, lag([Inventory]) over ( partition by  [PayPlan]
      ,[CategoryGroupCode]
      
      ,[CategorySubgroupCode]
      
      ,[GradeLevel]
	   order by [AmcosVersionId] ) as priorinv
	  from
	  (
SELECT [PayPlan]
      ,[CategoryGroupCode]
      ,[CategorySubgroupCode]
      ,[GradeLevel]
      ,sum([Inventory]) as Inventory
      ,[AmcosVersionId]
  FROM [data].[Inventory]
  where payplan in ('AE','AO','AWO','NO','NE','NWO','RE','RO','RWO')
  group by 
  [PayPlan]
      ,[CategoryGroupCode]
      ,[CategorySubgroupCode]
      ,[GradeLevel]
	  ,[AmcosVersionId]
  ) as a
  ) as b