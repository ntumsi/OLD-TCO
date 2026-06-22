CREATE VIEW data.TrainingAll
AS
SELECT PayPlan,
       NULL AS CMF,
       NULL AS MOS,
       CourseType,
       APPN,
       GradeType,
       GradeLevel,
       WeaponSystemId,
       Amount
FROM load_training.TrainingArmy
UNION ALL
SELECT PayPlan,
       CMF,
       NULL AS MOS,
       CourseType,
       APPN,
       GradeType,
       GradeLevel,
       WeaponSystemId,
       Amount
FROM load_training.TrainingCMF
UNION ALL
SELECT PayPlan,
       CMF,
       MOS,
       CourseType,
       APPN,
       GradeType,
       GradeLevel,
       WeaponSystemId,
       Amount
FROM load_training.TrainingMOS;