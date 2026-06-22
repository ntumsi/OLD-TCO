-- Stored Procedure

-- =============================================
-- Author:Dan Hogan
-- Create date: 9/26/2018
-- Updates:
--    1/18/2019 – adds new DMDC pay types, updates pay caps and adds aggregation (sum/max) to final table
-- Description:      Special Pays calculation
-- Considerations: this script relies on a processed DMDC pay table and assumes necessary CategorySubgroupCode conversions/adjustments 
-- and a bounce against inventory is handled in that script, before the work here takes place
-- Dependencies: dmdc_pay_processed & lookup.CMF_Branch_FA
-- to see all of the intermediate calculations/tables set this variable to 1, otherwise set it to 0
-- =============================================
CREATE PROCEDURE [crunch].[CostOfSpecialPays]
    @AmcosVersionId INT = -1,
    @CrunchTime AS SMALLDATETIME = NULL,
    @Debug AS BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsValidAmcosVersion BIT = crunch.ValidateAmcosVersion(@AmcosVersionId);

    IF (@IsValidAmcosVersion = 0)
        RETURN 0;

    IF (@CrunchTime IS NULL)
        SET @CrunchTime = CONVERT(SMALLDATETIME, GETDATE());

    DROP TABLE IF EXISTS #DMDCSpecialPayProcessed;
    CREATE TABLE #DMDCSpecialPayProcessed
    (
        PayType NVARCHAR(255) NULL,
        PayPlan NVARCHAR(3) NULL,
        CategoryGroupCode NVARCHAR(2) NULL,
        CategorySubgroupCode NVARCHAR(4) NULL,
        GradeType NVARCHAR(3) NULL,
        GradeLevel TINYINT NULL,
        avg_cost FLOAT NULL,
        AmcosVersionId INT NULL,
        avg_annual_pay FLOAT NULL,
        avg_annual_payments FLOAT NULL,
        CostElementId INT NULL,
        pay_cap FLOAT NULL,
        capped_avg_mpa_pay FLOAT NULL,
        aggregation_group NVARCHAR(50) NULL
    );

    INSERT INTO #DMDCSpecialPayProcessed
    (
        PayType,
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        avg_cost,
        AmcosVersionId,
        avg_annual_pay,
        avg_annual_payments,
        CostElementId,
        pay_cap,
        capped_avg_mpa_pay,
        aggregation_group
    )
    SELECT PayType,
           PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           avg_cost,
           AmcosVersionId,
           avg_annual_pay,
           avg_annual_payments,
           0 AS CostElementId,
           0.0 AS pay_cap,
           0.0 AS capped_avg_mpa_pay,
           '' AS aggregation_group
    FROM crunch.PayProcessed
    WHERE AmcosVersionId = @AmcosVersionId
          --if there is no pay then don't worry about the row
          AND avg_cost > 0
          AND
          (
              PayType IN (
                             --the following pay types have broad applicability so we'll take them for any pay plan
                             'All Hazardous Duty Pays', 'Aviation Career Incentive Pay',
                             'Board Certification Pay-Veterinarians', 'Career Sea Pay',
                             'Dental Officers Incentive Special Pay', 'Dental Officers Variable Special Pay',
                             'Diving Duty Pay', 'FLPB Total', 'Hardship Pay for Certain Places',
                             'Hardship Pay for Designated Area', 'Hardship Pay-Mission Assignment',
                             'Hostile Fire and Imminent Danger Pay', 'Medical Officer Additional Special Pay',
                             'Medical Officer Board Certified Pay', 'Medical Officer Incentive Special Pay',
                             'Medical Officer Multi-Year Special Pay Bonus', 'Medical Officer Variable Special Pay',
                             'Military Occ Spclty Conversion Bonus', 'Optometrist Regular Special Pay',
                             'Registered Nurse Accession Bonus', 'Veterinarians Special Pay',
                             'Dental Officers Board Certification Pay', 'Non-Phys Hlthcare Provider Board Cert Pay',
                             'Dental Officers Additional Special Pay', 'Health Profession Officers Retention Bonus',
                             'Incentive Pay for Reg Nurse Anesthetists', 'Special Duty Assignment Pay-Enlisted',
                             'Aviator Retention Bonus', 'Selected Reserve Critically Short Wartime Health S',
							 'Special Pay for Extending Duty at Designated Locations Overseas (Also called Overseas Tour Extension'
                         --'Retention Bonus for Mbrs in a Critical Skill' -> "Effective 7 December 2017 the CSAB program has been suspended pending reauthorization"

                         )
              OR
              --there are some pay types which regardless of what the data says should only be applied to the reserve components
              --this could because a soldier has switched between reserve/active and the payment is a risidual and it would be innaccurate for AMCOS to report that
              (
                  PayPlan NOT IN ( 'AE', 'AO', 'AWO' )
                  AND PayType IN (   'Designated Unit Pay',
                                     --'Sel Res Enlisted Accession Bonus', -> accounted for in Avg Cost of Recruiting
                                     --'Sel Res Enlisted Affiliation Bonus', -> accounted for in Avg Cost of Recruiting
                                     --'Sel Res Officer Accession Bonus',-> accounted for in Avg Cost of Officer Acquisition
                                     --'Sel Res Officer Affiliation Bonus', -> accounted for in Avg Cost of Officer Acquisition
                                     'Bonus for IRR and ING', 'Incapacitation Pay'
                                 )
              ) --end our reserve stipulation
          ); --end our pay type stipulations

    -- ###########################
    -- AMCOS CE Name: NA
    -- DMDC Pay Name: Retention Bonus for Mbrs in a Critical Skill
    -- FMR: 7A Ch: 61 Paragraph: 6102
    -- Army Reg: 
    -- Comments: Not authorized after 12/31/2017

    --Do nothing, pay cap of zero is correct

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: NA
    -- DMDC Pay Name: Designated Unit Pay
    -- FMR: 7A Ch: 58 Paragraph: 580208
    -- Army Reg: 
    -- Comments: Not authorized after 12/31/2017

    --Do nothing, pay cap of zero is correct

    -- ********** End ************


    -- ###########################
    -- AMCOS CE Name: NA
    -- DMDC Pay Name: Military Occ Spclty Conversion Bonus
    -- FMR: 7A Ch: 9 Paragraph: 0907
    -- Army Reg: 
    -- Comments: Not authorized after 12/31/2017

    --Do nothing, pay cap of zero is correct

    -- ********** End ************

    -- ###########################
    -- DMDC Pay Name: Retention Bonus for Mbrs in a Critical Skill
    -- FMR: 7A Ch: 9 Paragraph: 0904
    -- Army Reg: HRC Adjutant General Directorate
    -- Comments: Not authorized after 12/31/2017

    --Do nothing, pay cap of zero is correct

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Incapacitation Pay
    -- DMDC Pay Name: Incapacitation Pay
    -- FMR: 7A Ch: 57 Paragraph: 570607
    -- Army Reg: 
    -- Comments: This is an income replacement policy not to exceed 6 months so the max pay varies greatly 
    -- depending on the soldier Grade & YOS, therefore no cap is appropriate

    /* set the pay cap to a -1, which is no cap */
    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = -1,
        CostElementId = CASE
                            WHEN PayPlan = 'NE' THEN
                                3936
                            WHEN PayPlan = 'RE' THEN
                                3939
                            WHEN PayPlan = 'NO' THEN
                                3937
                            WHEN PayPlan = 'RO' THEN
                                3940
                            WHEN PayPlan = 'NWO' THEN
                                3938
                            WHEN PayPlan = 'RWO' THEN
                                3941
                        END
    WHERE PayType = 'Incapacitation Pay';

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Hostile Fire and Imminent Danger Pay
    -- DMDC Pay Name: Hostile Fire and Imminent Danger Pay
    -- FMR: 7A Ch: 10 Paragraph: 100202
    -- Army Reg: 
    -- Comments: 

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 225 * 12,
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                3927
                            WHEN PayPlan = 'NE' THEN
                                3930
                            WHEN PayPlan = 'RE' THEN
                                3933
                            WHEN PayPlan = 'AO' THEN
                                3928
                            WHEN PayPlan = 'NO' THEN
                                3931
                            WHEN PayPlan = 'RO' THEN
                                3934
                            WHEN PayPlan = 'AWO' THEN
                                3929
                            WHEN PayPlan = 'NWO' THEN
                                3932
                            WHEN PayPlan = 'RWO' THEN
                                3935
                        END
    WHERE PayType = 'Hostile Fire and Imminent Danger Pay';

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Hazardous Duty Pay
    -- DMDC Pay Name: All Hazardous Duty Pays
    -- FMR: 7A Ch: 10 Paragraph: 100202
    -- Army Reg: 
    -- Comments: the max is $225 (HALO) per month but you can rcv as many as 2 HDIPs simultaneously, the max for other than HALO is $150/month
	-- Update: the max is now $240 (HALO) Current as of March 2026


    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = (225 * 12) + (150 * 12),
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                50
                            WHEN PayPlan = 'NE' THEN
                                3921
                            WHEN PayPlan = 'RE' THEN
                                3924
                            WHEN PayPlan = 'AO' THEN
                                158
                            WHEN PayPlan = 'NO' THEN
                                3922
                            WHEN PayPlan = 'RO' THEN
                                3925
                            WHEN PayPlan = 'AWO' THEN
                                232
                            WHEN PayPlan = 'NWO' THEN
                                3923
                            WHEN PayPlan = 'RWO' THEN
                                3926
                        END
    WHERE PayType = 'All Hazardous Duty Pays';


    -- ********** End ************


    -- ###########################
    -- AMCOS CE Name: Avg Cost of Avg Cost of Harship Duty Pay
    -- DMDC Pay Names
    --Hardship Pay for Certain Places
    --Hardship Pay for Designated Area
    --Hardship Pay-Mission Assignment
    -- FMR: 7A Ch: 17 Paragraph: 1703
    -- Army Reg: 
    -- Comments: Certain Places/Designated Area not in the FMR but HDP-Location appears similar

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 150 * 12,
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                3948
                            WHEN PayPlan = 'NE' THEN
                                3951
                            WHEN PayPlan = 'RE' THEN
                                3954
                            WHEN PayPlan = 'AO' THEN
                                3949
                            WHEN PayPlan = 'NO' THEN
                                3952
                            WHEN PayPlan = 'RO' THEN
                                3955
                            WHEN PayPlan = 'AWO' THEN
                                3950
                            WHEN PayPlan = 'NWO' THEN
                                3953
                            WHEN PayPlan = 'RWO' THEN
                                3956
                        END
    WHERE PayType IN ( 'Hardship Pay for Certain Places', 'Hardship Pay for Designated Area',
                       'Hardship Pay-Mission Assignment'
                     );


    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 450 * 12,
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                3948
                            WHEN PayPlan = 'NE' THEN
                                3951
                            WHEN PayPlan = 'RE' THEN
                                3954
                        END
    WHERE PayType IN ( 'Special Duty Assignment Pay-Enlisted', 'Special Pay for Extending Duty at Designated Locations Overseas (Also called Overseas Tour Extension')
          AND GradeType = 'E';

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Foreign Language Pay
    -- DMDC Pay Name: FLPB Total
    -- FMR: 7A Ch: 19 Paragraph: 190205
    -- Army Reg: 
    -- Comments: 

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 12000,
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                51
                            WHEN PayPlan = 'NE' THEN
                                3915
                            WHEN PayPlan = 'RE' THEN
                                3918
                            WHEN PayPlan = 'AO' THEN
                                159
                            WHEN PayPlan = 'NO' THEN
                                3916
                            WHEN PayPlan = 'RO' THEN
                                3919
                            WHEN PayPlan = 'AWO' THEN
                                233
                            WHEN PayPlan = 'NWO' THEN
                                3917
                            WHEN PayPlan = 'RWO' THEN
                                3920
                        END
    WHERE PayType = 'FLPB Total';

    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Diving Duty Pay
    -- DMDC Pay Name: Diving Duty Pay
    -- FMR: 7A Ch: 11 Paragraph: 110401
    -- Army Reg: AR611-75: 2-16 Selection Criteria & HRC Hazardous Duty Pay
    -- Comments: Different amounts for O/WO & E

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 240 * 12
    WHERE PayType = 'Diving Duty Pay'
          AND
          (
              ( --begin O
                  CategoryGroupCode IN ( '11', '18', '60', '61', '62', '65' )
                  AND GradeType IN ( 'O' )
              ) --end O
              OR
              ( --W
                  CategorySubgroupCode IN ( '180A' )
                  AND GradeType IN ( 'W' )
              ) --end W
          );

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 340 * 12
    WHERE PayType = 'Diving Duty Pay'
          AND
          (
              ( --begin O
                  CategoryGroupCode IN ( '12', '18' )
                  AND GradeType = 'O'
              ) --end O
              OR
              ( --E
                  (
                      CategorySubgroupCode IN ( '68W', '12D' )
                      OR CategoryGroupCode IN ( '18' )
                  )
                  AND GradeType = 'E'
              ) --end E
              OR
              ( --W
                  CategoryGroupCode IN ( '18' )
                  AND GradeType = 'W'
              ) --end W
          );

    UPDATE #DMDCSpecialPayProcessed
    SET CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                47
                            WHEN PayPlan = 'NE' THEN
                                3909
                            WHEN PayPlan = 'RE' THEN
                                3912
                            WHEN PayPlan = 'AO' THEN
                                156
                            WHEN PayPlan = 'NO' THEN
                                3910
                            WHEN PayPlan = 'RO' THEN
                                3913
                            WHEN PayPlan = 'AWO' THEN
                                230
                            WHEN PayPlan = 'NWO' THEN
                                3911
                            WHEN PayPlan = 'RWO' THEN
                                3914
                        END
    WHERE PayType = 'Diving Duty Pay';


    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Consolidated Special Pays
    -- DMDC Pay Names: Numerous
    -- FMR: 7A Ch: 5 Paragraph: 0502
    -- Army Reg: 
    -- Comments: caps are based on speciality which do not always translate well to AOCs so we use the overall maximum for each type

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 100000,
        aggregation_group = 'medical incentive'
    WHERE PayType IN ( 'Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                       'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                       'Medical Officer Incentive Special Pay', 'Medical Officer Variable Special Pay',
                       'Optometrist Regular Special Pay', 'Veterinarians Special Pay', 'Selected Reserve Critically Short Wartime Health S'
                     )
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'DENTAL CORPS', 'MEDICAL CORPS' )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              );

	IF @Debug = 1
	BEGIN

		SELECT COUNT(*) AS TotalMedicalCap100000 FROM #DMDCSpecialPayProcessed WHERE pay_cap = 100000
	END


    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 15000,
        aggregation_group = 'medical incentive'
    WHERE PayType IN ( 'Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                       'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                       'Medical Officer Incentive Special Pay', 'Medical Officer Variable Special Pay',
                       'Optometrist Regular Special Pay', 'Veterinarians Special Pay',
                       'Incentive Pay for Reg Nurse Anesthetists'
                     )
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                         'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                         'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES', 'DENTAL CORPS'
                                       )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              );

	IF @Debug = 1
	BEGIN

		SELECT COUNT(*) AS TotalMedicalCap100000_AFTER_OVERWRITE FROM #DMDCSpecialPayProcessed WHERE pay_cap = 100000
	END

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 30000
    WHERE PayType IN ( 'Registered Nurse Accession Bonus' )
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                         'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                         'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES'
                                       )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              );


    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 75000,
        aggregation_group = 'medical multiyear'
    WHERE PayType IN ( 'Medical Officer Multi-Year Special Pay Bonus', 'Health Profession Officers Retention Bonus' )
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'VETERINARY CORPS', 'ARMY MEDICAL SPECIALIST CORPS', 'ARMY NURSE CORPS',
                                         'MEDICAL SERVICE CORPS', 'MEDICAL', 'HEALTH SERVICES', 'LABORATORY SCIENCES',
                                         'PREVENTIVE MEDICINE SCIENCES', 'BEHAVIORAL SCIENCES', 'DENTAL CORPS'
                                       )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              );

    UPDATE #DMDCSpecialPayProcessed
    SET CostElementId = CASE
                            WHEN PayPlan = 'AO' THEN
                                3906
                            WHEN PayPlan = 'NO' THEN
                                3908
                            WHEN PayPlan = 'RO' THEN
                                3907
                        END
    WHERE PayType IN ( 'Dental Officers Additional Special Pay', 'Dental Officers Incentive Special Pay',
                       'Dental Officers Variable Special Pay', 'Medical Officer Additional Special Pay',
                       'Medical Officer Incentive Special Pay', 'Medical Officer Multi-Year Special Pay Bonus',
                       'Medical Officer Variable Special Pay', 'Optometrist Regular Special Pay',
                       'Registered Nurse Accession Bonus', 'Veterinarians Special Pay',
                       'Incentive Pay for Reg Nurse Anesthetists', 'Health Profession Officers Retention Bonus'
                     );

    -- ********** End ************


    -- ###########################
    -- AMCOS CE Name: Avg Cost of Career Sea Pay
    -- DMDC Pay Name: FLPB Total
    -- FMR: 7A Ch: 18 Paragraph: 180504 & Table 18-2
    -- Army Reg: 
    -- Comments: 

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 534 * 12,
        CostElementId = CASE
                            WHEN PayPlan = 'AE' THEN
                                3897
                            WHEN PayPlan = 'NE' THEN
                                3900
                            WHEN PayPlan = 'RE' THEN
                                3903
                            WHEN PayPlan = 'AO' THEN
                                3898
                            WHEN PayPlan = 'NO' THEN
                                3901
                            WHEN PayPlan = 'RO' THEN
                                3904
                            WHEN PayPlan = 'AWO' THEN
                                3899
                            WHEN PayPlan = 'NWO' THEN
                                3902
                            WHEN PayPlan = 'RWO' THEN
                                3905
                        END
    WHERE PayType = 'Career Sea Pay'
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'TRANSPORTATION CORPS' )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              );


    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Board Certification Pay (BCP)
    -- DMDC Pay Name: Several
    -- FMR: 7A Ch: 5 Paragraph: 0505
    -- Army Reg: 
    -- Comments: 

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 6000
    WHERE PayType IN ( 'Medical Officer Board Certified Pay', 'Dental Officers Board Certification Pay',
                       'Board Certification Pay-Veterinarians', 'Non-Phys Hlthcare Provider Board Cert Pay'
                     )
          AND
          (
              --applies TO ANY medical professional
              LEFT(CategoryGroupCode, 1) = '6'
              OR CategoryGroupCode IN ( '72', '73' )
          )
          AND GradeType = 'O';



    UPDATE #DMDCSpecialPayProcessed
    SET CostElementId = CASE
                            WHEN PayPlan = 'AO' THEN
                                3894
                            WHEN PayPlan = 'NO' THEN
                                3896
                            WHEN PayPlan = 'RO' THEN
                                3895
                        END
    WHERE PayType IN ( 'Medical Officer Board Certified Pay', 'Dental Officers Board Certification Pay',
                       'Board Certification Pay-Veterinarians', 'Non-Phys Hlthcare Provider Board Cert Pay'
                     );
    -- ********** End ************

    -- ###########################
    -- AMCOS CE Name: Avg Cost of Aviation Career Incentive Pay
    -- DMDC Pay Name: Aviation Career Incentive Pay
    -- FMR: 7A Ch: 22 Paragraph: Tables 22-1 & 22-2 and 37 U.S.C 334(b)
    -- Army Reg: AR 37–104–4:9-3
    -- Comments: AR is vague so based on the DMDC data the eligilibity listing is inferred since those positions 
    --have either a direct flight responsibility or indirect (flight medical).  The HRC limit reigns which caps at $250/mo for Officers, 
    --the limits do not apply to warrants so the FMR limit reigns


    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 250 * 12
    WHERE PayType = 'Aviation Career Incentive Pay'
          AND
          (
              CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'AVIATION', 'SPECIAL FORCES' )
                        AND GradeType = 'O'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              )
              OR CategorySubgroupCode IN ( '67J' )
          )
          AND #DMDCSpecialPayProcessed.GradeType = 'O';

    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 350 * 12
    WHERE PayType = 'Aviation Career Incentive Pay'
          AND CategoryGroupCode IN
              (
                  SELECT Code
                  FROM lookup.CMF_Branch_FA
                  WHERE Description IN ( 'AVIATION' )
                        AND GradeType = 'W'
                        AND (@AmcosVersionId
                        BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                            )
              )
          AND #DMDCSpecialPayProcessed.GradeType = 'W';

    --the following is new in the 2018 DMDC pay and I don't see a published cap for it yet
    UPDATE #DMDCSpecialPayProcessed
    SET pay_cap = 25000
    WHERE PayType = 'Aviator Retention Bonus'
          AND #DMDCSpecialPayProcessed.GradeType = 'W';

    UPDATE #DMDCSpecialPayProcessed
    SET CostElementId = CASE
                            WHEN PayPlan = 'AO' THEN
                                3888
                            WHEN PayPlan = 'NO' THEN
                                3892
                            WHEN PayPlan = 'RO' THEN
                                3890
                            WHEN PayPlan = 'AWO' THEN
                                3889
                            WHEN PayPlan = 'NWO' THEN
                                3893
                            WHEN PayPlan = 'RWO' THEN
                                3891
                        END
    WHERE PayType IN ( 'Aviation Career Incentive Pay', 'Aviator Retention Bonus' );

    -- ********** End ************

    --implement pay caps
    UPDATE #DMDCSpecialPayProcessed
    SET capped_avg_mpa_pay = CASE
                                 WHEN pay_cap = -1 THEN
                                     avg_cost --pay caps should be ignored as those indicate no pay cap
                                 WHEN pay_cap > -1
                                      AND pay_cap >= avg_cost THEN
                                     avg_cost --avg pay below cap so return avg pay
                                 ELSE
                                     pay_cap  --avg pay above cap so return cap
                             END;

    IF @Debug = 1 BEGIN
		SELECT 'We are here'
		SELECT CountAllAvgOver/CountAll * 100 AS PercentOverAll, CountOfficerAvgOver/CountOfficers * 100 AS PercentOfficersOver FROM (
		SELECT 
		(SELECT COUNT(*) CountAll FROM #DMDCSpecialPayProcessed) AS CountAll,
		(SELECT COUNT(*) CountOfficers FROM #DMDCSpecialPayProcessed) AS CountOfficers,
		(SELECT COUNT(*) AS COUNTOfficerAvgOver FROM #DMDCSpecialPayProcessed WHERE pay_cap < avg_cost AND payplan IN ('AO','NO','RO')) AS CountOfficerAvgOver,
		(SELECT COUNT(*) AS COUNTAllAvgOver FROM #DMDCSpecialPayProcessed WHERE pay_cap < avg_cost) AS CountAllAvgOver
		) a		


	END
    --drop all the zero pay values so we're not inserting blanks and aggregate up to the AMCOS CE level from the DMDC pay type level
    DROP TABLE IF EXISTS #DMDCSpecialPayProcessedFinal;
    CREATE TABLE [#DMDCSpecialPayProcessedFinal]
    (
        [PayPlan] NVARCHAR(3) NULL,
        [CategoryGroupCode] NVARCHAR(4) NULL,
        [CategorySubgroupCode] NVARCHAR(4) NULL,
        [GradeType] NVARCHAR(3) NULL,
        [GradeLevel] TINYINT NULL,
        [avg_cost] FLOAT NULL,
        [AmcosVersionId] INT NULL,
        [avg_annual_pay] FLOAT NULL,
        [avg_annual_payments] FLOAT NULL,
        [CostElementId] INT NULL,
        [pay_cap] FLOAT NULL,
        [capped_avg_mpa_pay] FLOAT NULL
    );

    INSERT INTO #DMDCSpecialPayProcessedFinal
    (
        PayPlan,
        CategoryGroupCode,
        CategorySubgroupCode,
        GradeType,
        GradeLevel,
        CostElementId,
        capped_avg_mpa_pay,
        AmcosVersionId
    )
    SELECT PayPlan,
           CategoryGroupCode,
           CategorySubgroupCode,
           GradeType,
           GradeLevel,
           CostElementId,
           SUM(capped_avg_mpa_pay),
           @AmcosVersionId
    FROM
    (
        --because of the consolidated special pas transition we need to do an avg by groups of pay types before summing
        --so we don't double count for instance is there is pay in one time one year then it transitions to a new 
        --pay type the following year we'd be double counting by summing two numbers which really should be averaged
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               CostElementId,
               AVG(capped_avg_mpa_pay) AS capped_avg_mpa_pay,
               aggregation_group
        FROM #DMDCSpecialPayProcessed
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel,
                 CostElementId,
                 aggregation_group
    ) AS a
    WHERE capped_avg_mpa_pay > 0
    GROUP BY PayPlan,
             CategoryGroupCode,
             CategorySubgroupCode,
             GradeType,
             GradeLevel,
             CostElementId;
    IF @Debug = 1 BEGIN
		SELECT 'We are now here X'
	END

    --to prevent costs with no inventory from coming in

    DELETE FROM #DMDCSpecialPayProcessedFinal
    WHERE PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + CategorySubgroupCode NOT IN
          (
              SELECT DISTINCT
                     PayPlan + CAST(GradeLevel AS NVARCHAR(2)) + CategorySubgroupCode
              FROM data.KnownInventory
              WHERE AmcosVersionId = @AmcosVersionId
          );


    IF @Debug = 1
    BEGIN
        SELECT PayType,
               PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               avg_cost,
               AmcosVersionId,
               avg_annual_pay,
               avg_annual_payments,
               CostElementId,
               pay_cap,
               capped_avg_mpa_pay,
               aggregation_group
        FROM #DMDCSpecialPayProcessed
        WHERE CategorySubgroupCode = '73a'
              AND GradeLevel = 1
        ORDER BY PayType,
                 CategoryGroupCode,
                 capped_avg_mpa_pay,
                 avg_cost ASC;

        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               GradeType,
               GradeLevel,
               CostElementId,
               capped_avg_mpa_pay
        FROM #DMDCSpecialPayProcessedFinal;
    --SELECT * FROM dbo.dmdc_pay WHERE [pay type] LIKE '%optom%' AND [primary service occupation code]='63P'
    END;

	IF @Debug = 1 BEGIN
		SELECT 'We have reached the end of Debug'
	END

    IF @Debug = 0
    BEGIN



        -- clear out the existing cost table for all the CE IDs we are about to insert values for
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;

        DELETE FROM crunch.Costs_RE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId IN
              (
                  SELECT CostElementId
                  FROM lookup.CostElement
                  WHERE CostElementCategory = 'Special Pays'
              )
              AND AmcosVersionId = @AmcosVersionId;

        --we already have the IDs in the table so we only need one insert for each pay plan
        --AE



        INSERT INTO crunch.Costs_AE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;

        --RE
        INSERT INTO crunch.Costs_RE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;
        --NE
        INSERT INTO crunch.Costs_NE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;

        --AO
        INSERT INTO crunch.Costs_AO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;
        --RO
        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;
        --AO
        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;

        --AWO
        INSERT INTO crunch.Costs_AWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;
        --RWO
        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;
        --NWO
        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               CostElementId,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 CostElementId,
                 GradeType,
                 GradeLevel;

        --Insert Totals
        --AE
        DELETE FROM crunch.Costs_AE
        WHERE CostElementId = 55
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_AE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               55,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --NE
        DELETE FROM crunch.Costs_NE
        WHERE CostElementId = 3942
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_NE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3942,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --RE
        DELETE FROM crunch.Costs_RE
        WHERE CostElementId = 3945
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_RE
        (
            [PayPlan],
            [CMF],
            [MOS],
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3945,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RE'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --AO
        DELETE FROM crunch.Costs_AO
        WHERE CostElementId = 162
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_AO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               162,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --NO
        DELETE FROM crunch.Costs_NO
        WHERE CostElementId = 3943
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_NO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3943,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --RO
        DELETE FROM crunch.Costs_RO
        WHERE CostElementId = 3946
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_RO
        (
            [PayPlan],
            [CMF],
            AOC,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3946,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --AWO
        DELETE FROM crunch.Costs_AWO
        WHERE CostElementId = 236
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_AWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId,
            LocationId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               236,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId,
               -1
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'AWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --NWO
        DELETE FROM crunch.Costs_NWO
        WHERE CostElementId = 3944
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_NWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3944,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'NWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;

        --RWO
        DELETE FROM crunch.Costs_RWO
        WHERE CostElementId = 3947
              AND AmcosVersionId = @AmcosVersionId;

        INSERT INTO crunch.Costs_RWO
        (
            [PayPlan],
            Branch,
            WOMOS,
            [CostElementId],
            [GradeType],
            [GradeLevel],
            [WeaponSystemId],
            [Amount],
            CrunchTime,
            AmcosVersionId
        )
        SELECT PayPlan,
               CategoryGroupCode,
               CategorySubgroupCode,
               3947,
               GradeType,
               GradeLevel,
               -1,
               SUM(capped_avg_mpa_pay),
               @CrunchTime,
               @AmcosVersionId
        FROM #DMDCSpecialPayProcessedFinal
        WHERE PayPlan = 'RWO'
        GROUP BY PayPlan,
                 CategoryGroupCode,
                 CategorySubgroupCode,
                 GradeType,
                 GradeLevel;
    END;

END;
GO
