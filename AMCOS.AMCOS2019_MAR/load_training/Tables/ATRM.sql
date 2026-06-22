CREATE TABLE [load_training].[ATRM] (
    [SchoolCode]     NVARCHAR (25)    NULL,
    [CourseNumber]   NVARCHAR (255)   NULL,
    [CourseTitle]    NVARCHAR (255)   NULL,
    [Location]       NVARCHAR (255)   NULL,
    [Activity]       NVARCHAR (255)   NULL,
    [Length_weeks]   NUMERIC (18, 10) NULL,
    [EGRADS]         NUMERIC (18, 10) NULL,
    [ModalGrade]     NVARCHAR (10)    NULL,
    [Frequency]      NUMERIC (18, 10) NULL,
    [FlyingHours]    NUMERIC (18, 10) NULL,
    [ICH]            NUMERIC (18, 10) NULL,
    [MPA_Cost]       NUMERIC (18, 10) NULL,
    [OMACivPay_Cost] NUMERIC (18, 10) NULL,
    [OMANonPay_Cost] NUMERIC (18, 10) NULL,
    [Other_Cost]     NUMERIC (18, 10) NULL,
    [AmcosVersionId] INT              NULL
);





