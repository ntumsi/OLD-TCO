
CREATE PROCEDURE [web].[PMAddSkill]
    @UserID VARCHAR(50) ,
    @ProjectID INT ,
    @CategoryID INT ,
    @PayPlan VARCHAR(10) ,
    @CategoryGroupCode VARCHAR(10) ,
    @CategorySubGroupCode VARCHAR(10) ,
    @Type VARCHAR(5) ,
    @AreaCode VARCHAR(50) ,
    @LocalityID INT ,
    @SpecialRateTableNumber NVARCHAR(4) ,
    @GradeType NVARCHAR(3) ,
    @GradeLevel TINYINT ,
    @activeDays INT ,
    @overheadPct FLOAT ,
    @FunctionalAreaCode NVARCHAR(50) ,
    @CostCenterCode NVARCHAR(50) ,
    @StateCountry NVARCHAR(50)
AS
    IF @PayPlan IN ( 'WG', 'WL', 'WS' )
        SET @CategorySubGroupCode = @CategoryGroupCode; -- 5/30/2013

    IF EXISTS ( SELECT  0
                FROM    webuser.PMCategorySkill
                WHERE   UserId = @UserID
                        AND ProjectId = @ProjectID
                        AND CategoryId = @CategoryID
                        AND PayPlan = @PayPlan
                        AND CategoryGroupCode = @CategoryGroupCode
                        AND CategorySubGroupCode = @CategorySubGroupCode
                        AND Type = @Type
                        AND AreaCode = @AreaCode
                        AND LocalityId = @LocalityID
                        AND GradeType = @GradeType
                        AND GradeLevel = @GradeLevel
                        AND FunctionalAreaCode = @FunctionalAreaCode
                        AND CostCenterCode = @CostCenterCode
                        AND StateCountry = @StateCountry )
        SELECT  SkillId
        FROM    webuser.PMCategorySkill
        WHERE   UserId = @UserID
                AND ProjectId = @ProjectID
                AND CategoryId = @CategoryID
                AND PayPlan = @PayPlan
                AND CategoryGroupCode = @CategoryGroupCode
                AND CategorySubGroupCode = @CategorySubGroupCode
                AND Type = @Type
                AND AreaCode = @AreaCode
                AND LocalityId = @LocalityID
                AND GradeType = @GradeType
                AND GradeLevel = @GradeLevel
                AND FunctionalAreaCode = @FunctionalAreaCode
                AND CostCenterCode = @CostCenterCode
                AND StateCountry = @StateCountry;
    ELSE
        BEGIN 
            INSERT  INTO webuser.PMCategorySkill
                    ( UserId ,
                      ProjectId ,
                      CategoryId ,
                      PayPlan ,
                      CategoryGroupCode ,
                      CategorySubGroupCode ,
                      Type ,
                      AreaCode ,
                      LocalityId ,
                      GradeType ,
                      GradeLevel ,
                      activeDays ,
                      overheadPct ,
                      FunctionalAreaCode ,
                      CostCenterCode ,
                      StateCountry
                    )
            VALUES  ( @UserID ,
                      @ProjectID ,
                      @CategoryID ,
                      @PayPlan ,
                      @CategoryGroupCode ,
                      @CategorySubGroupCode ,
                      @Type ,
                      @AreaCode ,
                      @LocalityID ,
                      @GradeType ,
                      @GradeLevel ,
                      @activeDays ,
                      @overheadPct ,
                      @FunctionalAreaCode ,
                      @CostCenterCode ,
                      @StateCountry
                    ); 
            SELECT  @@IDENTITY;
        END;