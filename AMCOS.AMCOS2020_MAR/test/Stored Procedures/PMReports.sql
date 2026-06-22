
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
--exec test.pmreports
CREATE PROCEDURE test.PMReports
-- Add the parameters for the stored procedure here

--@amcosversionidprior INT = -1,
--@amcosversionidnew INT = -1,
--@Summary NVARCHAR(20) = '-1',
--@SumToGradeLevelTotal BIT = 0,
--@PayPlanorPayPlanType NVARCHAR(50) = '-1'
AS
BEGIN

    DROP TABLE IF EXISTS #MyResults;
    CREATE TABLE #MyResults
    (
        ProjectId INT,
        ProjectName NVARCHAR(500),
        YearStart INT,
        YearDuration INT,
        UserId NVARCHAR(500),
        TestInflation NVARCHAR(MAX),
        TestInventory NVARCHAR(MAX),
        TestReport NVARCHAR(MAX)
    );
    INSERT INTO #MyResults
    (
        ProjectId,
        ProjectName,
        YearStart,
        YearDuration,
        UserId
    )
    SELECT ProjectId,
           ProjectName,
           YearStart,
           YearDuration,
           UserId
    FROM webuser.PMProject;

    DECLARE @projectid INT;

    DECLARE cursor_PMProject CURSOR FOR SELECT ProjectId FROM #MyResults;

    OPEN cursor_PMProject;


    FETCH NEXT FROM cursor_PMProject
    INTO @projectid;

    --set up the report so that it pulls all data (this is code version of the check boxes on the report version)
    DELETE FROM webuser.PMReport
    WHERE CategoryId IN
          (
              SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId = @projectid
          );
    INSERT INTO webuser.PMReport
    (
        CategoryId,
        PayPlan
    )
    SELECT CategoryId,
           PayPlan
    FROM webuser.PMCategorySkill
    WHERE CategoryId IN
          (
              SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId = @projectid
          )
    GROUP BY CategoryId,
             PayPlan;


    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @emptyproject BIT;
        IF NOT EXISTS
        (
            SELECT *
            FROM webuser.PMCategorySkillInventory
            WHERE SkillId IN
                  (
                      SELECT SkillId
                      FROM webuser.PMCategorySkill
                      WHERE CategoryId IN
                            (
                                SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId = @projectid
                            )
                  )
        )
            SET @emptyproject = 1;
        ELSE
            SET @emptyproject = 0;
        -- ##### inflation test ######
        BEGIN TRY
            IF EXISTS
            (
                SELECT *
                FROM web.GetPMReportInflationRateHeader(@projectid, 202101)
            )
                UPDATE #MyResults
                SET TestInflation = 'pass-results returned'
                WHERE ProjectId = @projectid;
            ELSE IF @emptyproject = 1
                UPDATE #MyResults
                SET TestInflation = 'pass-empty project'
                WHERE ProjectId = @projectid;
            ELSE
                UPDATE #MyResults
                SET TestInflation = 'fail-empty set'
                WHERE ProjectId = @projectid;
        END TRY
        BEGIN CATCH
            UPDATE #MyResults
            SET TestInflation = 'fail-error:' +
                                (
                                    SELECT ERROR_MESSAGE() AS ErrorMessage
                                )
            WHERE ProjectId = @projectid;
        END CATCH;
        -- ##### inventory  test ######
        BEGIN TRY
            EXEC [web].[PMProjectInventory] @projectid, 1;
            IF @@rowcount > 0
                UPDATE #MyResults
                SET TestInventory = 'pass-results returned'
                WHERE ProjectId = @projectid;
            ELSE IF @emptyproject = 1
                UPDATE #MyResults
                SET TestInventory = 'pass-empty project'
                WHERE ProjectId = @projectid;
            ELSE
                UPDATE #MyResults
                SET TestInventory = 'fail-empty set'
                WHERE ProjectId = @projectid;
        END TRY
        BEGIN CATCH
            UPDATE #MyResults
            SET TestInventory = 'fail-error:' +
                                (
                                    SELECT ERROR_MESSAGE() AS ErrorMessage
                                )
            WHERE ProjectId = @projectid;
        END CATCH;

        FETCH NEXT FROM cursor_PMProject
        INTO @projectid;

    END;

    CLOSE cursor_PMProject;

    DEALLOCATE cursor_PMProject;
    SELECT TestInflation,
           TestInventory,
           TestReport,
           COUNT(TestInflation) AS mycount
    FROM #MyResults
    GROUP BY TestInflation,
             TestInventory,
             TestReport;
    SELECT *
    FROM #MyResults
    WHERE --projectid=25611--
        TestInflation LIKE 'fail%'
        OR TestInventory LIKE 'fail%'
        OR TestReport LIKE 'fail%';



/*
SELECT * FROM  web.GetPMReportInflationRateHeader (25611,202101)
exec web.pmreport 25611,202101
declare @projectid int = 25611
begin try
			IF EXISTS (SELECT * FROM  web.GetPMReportInflationRateHeader (@projectid,202101) )
				print 'pass-results returned' 
			ELSE IF NOT EXISTS (SELECT * FROM webuser.PMCategorySkillInventory WHERE SkillId IN (SELECT skillid FROM webuser.PMCategorySkill WHERE  CategoryId IN (SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId=@projectid)))
				print 'pass-empty project' 
			ELSE 
				print 'fail-empty set' 
		end try
		begin catch

		end catch

SELECT * FROM webuser.PMCategorySkillInventory WHERE  SkillId  IN (SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId= 26029))
SELECT * FROM webuser.PMProject WHERE ProjectId=26029
SELECT * FROM webuser.PMCategory WHERE ProjectId=26029
SELECT * FROM webuser.PMCategorySkill WHERE  CategoryId IN (SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId=26029)
SELECT * FROM webuser.PMCategorySkillInventory WHERE SkillId IN 
(SELECT skillid FROM webuser.PMCategorySkill WHERE  CategoryId IN (SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId=26029))

SELECT * FROM webuser.PMCategorySkillInventory WHERE SkillId IN (SELECT skillid FROM webuser.PMCategorySkill WHERE  CategoryId IN (SELECT CategoryId FROM webuser.PMCategory WHERE ProjectId=26033))
*/

END;