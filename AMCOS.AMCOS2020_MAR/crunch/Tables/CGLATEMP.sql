CREATE TABLE [crunch].[CGLATEMP] (
    [Id]             INT             IDENTITY (1, 1) NOT NULL,
    [PayPlan]        NVARCHAR (3)    NOT NULL,
    [GradeType]      NVARCHAR (1)    NOT NULL,
    [BaseSubgrp]     NVARCHAR (4)    NOT NULL,
    [BaseGL]         INT             NOT NULL,
    [InvSubgrp]      NVARCHAR (4)    NOT NULL,
    [InvGL]          INT             NOT NULL,
    [Inventory]      INT             NOT NULL,
    [ParentMOS]      NVARCHAR (4)    NULL,
    [AdjInv]         NUMERIC (18, 6) NULL,
    [CumulativeInv]  INT             NULL,
    [PercentShare]   NUMERIC (18, 6) NULL,
    [AmcosVersionId] INT             NOT NULL,
    [ParentShare]    NUMERIC (18, 6) NULL,
    CONSTRAINT [PK_CGLATEMP] PRIMARY KEY CLUSTERED ([Id] ASC)
);



