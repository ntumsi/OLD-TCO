CREATE TABLE [load_inventory].[WASS_Raw] (
    [Id]                       INT             IDENTITY (1, 1) NOT NULL,
    [PayPlan]                  NVARCHAR (3)    NOT NULL,
    [OccupationalSeriesNumber] NVARCHAR (5)    NOT NULL,
    [SAL_WAG]                  NUMERIC (16, 2) NULL,
    [GradeLevel]               NVARCHAR (2)    NOT NULL,
    [Step]                     NVARCHAR (2)    NOT NULL,
    [CityCode]                 NVARCHAR (4)    NOT NULL,
    [CountyCode]               NVARCHAR (3)    NOT NULL,
    [StateCode]                NVARCHAR (2)    NOT NULL,
    [Sex]                      NVARCHAR (50)   NOT NULL,
    [PayBasis]                 NVARCHAR (50)   NULL,
    [PayBasisDescription]      NVARCHAR (50)   NULL,
    [PayRateDeterm]            NVARCHAR (50)   NULL,
    [PayRateDetermDesc]        NVARCHAR (100)  NULL,
    [ST_TRANS]                 NVARCHAR (50)   NULL,
    [Count]                    INT             NOT NULL,
    [AmcosVersionId]           INT             NOT NULL
);









