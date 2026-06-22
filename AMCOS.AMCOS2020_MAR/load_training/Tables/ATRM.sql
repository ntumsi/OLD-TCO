CREATE TABLE [load_training].[ATRM] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [SchoolCode]     NVARCHAR (25)   NOT NULL,
    [CourseNumber]   NVARCHAR (50)   NOT NULL,
    [CourseTitle]    NVARCHAR (100)  NOT NULL,
    [Location]       NVARCHAR (100)  NOT NULL,
    [Activity]       NVARCHAR (100)  NOT NULL,
    [Length_weeks]   NUMERIC (18, 4) NOT NULL,
    [EGRADS]         NUMERIC (18, 4) NOT NULL,
    [ModalGrade]     NVARCHAR (10)   NOT NULL,
    [Frequency]      NUMERIC (18, 4) NULL,
    [FlyingHours]    NUMERIC (18, 4) NULL,
    [ICH]            NUMERIC (18, 4) NULL,
    [MPA_Cost]       NUMERIC (18, 4) CONSTRAINT [DF_ATRM_MPA_Cost] DEFAULT ((0)) NULL,
    [OMACivPay_Cost] NUMERIC (18, 4) CONSTRAINT [DF_ATRM_OMACivPay_Cost] DEFAULT ((0)) NULL,
    [OMANonPay_Cost] NUMERIC (18, 4) CONSTRAINT [DF_ATRM_OMANonPay_Cost] DEFAULT ((0)) NULL,
    [Other_Cost]     NUMERIC (18, 4) CONSTRAINT [DF_ATRM_Other_Cost] DEFAULT ((0)) NULL,
    [AmcosVersionId] INT             NOT NULL,
    CONSTRAINT [PK_ATRM] PRIMARY KEY NONCLUSTERED ([Id] ASC)
);












GO
CREATE CLUSTERED INDEX [ClusteredIndex-20240729-195108]
    ON [load_training].[ATRM]([SchoolCode] ASC, [CourseNumber] ASC, [CourseTitle] ASC, [Location] ASC, [Activity] ASC, [AmcosVersionId] ASC);



