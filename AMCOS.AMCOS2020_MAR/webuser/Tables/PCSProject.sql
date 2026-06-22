CREATE TABLE [webuser].[PCSProject] (
    [UserId]                        NVARCHAR (50)   NOT NULL,
    [ProjectName]                   NVARCHAR (50)   NOT NULL,
    [ProjectSaveDate]               DATETIME        NOT NULL,
    [ConversionType]                NVARCHAR (25)   NOT NULL,
    [Year]                          SMALLINT        NOT NULL,
    [Appropriation]                 NVARCHAR (25)   NOT NULL,
    [AmcosVersionId]                INT             NOT NULL,
    [OriginationId]                 INT             NOT NULL,
    [DestinationId]                 INT             NOT NULL,
    [CalculatedDistance]            INT             NULL,
    [NumberOfDaysHunting]           INT             NULL,
    [HouseHuntingHaveSpouse]        BIT             NULL,
    [SelfLodgingPerDiem]            NUMERIC (18, 2) NULL,
    [SpouseLodgingPerDiem]          NUMERIC (18, 2) NULL,
    [SelfMIEPerDiem]                NUMERIC (18, 2) NULL,
    [SpouseMIEPerDiem]              NUMERIC (18, 2) NULL,
    [HouseHuntingTotal]             NUMERIC (18, 2) NULL,
    [SpousePerDiemRate]             NUMERIC (18, 2) NULL,
    [POVMileage]                    INT             NULL,
    [PCSMaltRate]                   NUMERIC (18, 2) NULL,
    [MileageReimbursement]          NUMERIC (18, 2) NULL,
    [DependantMileageReimbursement] NUMERIC (18, 2) NULL,
    [TransportationSubTotal]        NUMERIC (18, 2) NULL,
    [NumberDaysTQSE]                INT             NULL,
    [TQSESelfPerDiemLodging]        NUMERIC (18, 2) NULL,
    [TQSESpousePerDiemLodging]      NUMERIC (18, 2) NULL,
    [TQSESelfPerDiemMIE]            NUMERIC (18, 2) NULL,
    [TQSESpousePerDiemMIE]          NUMERIC (18, 2) NULL,
    [TQSEPerDiemRate]               NUMERIC (18, 2) NULL,
    [TQSESpousePerDiemRate]         NUMERIC (18, 2) NULL,
    [TQSETotal]                     NUMERIC (18, 2) NULL,
    [TransportationType]            NVARCHAR (25)   NULL,
    [GHTransportationTotal]         NUMERIC (18, 2) NULL,
    [HHGTotalMileage]               INT             NULL,
    [HHGTotalWeight]                FLOAT (53)      NULL,
    [HHGMaxWeight]                  INT             NULL,
    [HHGEstimatedCostPerMile]       NUMERIC (18, 2) NULL,
    [HHGEstimatedCostPerPound]      NUMERIC (18, 2) NULL,
    [HHGCostByTotalMiles]           NUMERIC (18, 2) NULL,
    [HHGCostByTotalWeight]          NUMERIC (18, 2) NULL,
    [SubtotalHHG]                   NUMERIC (18, 2) NULL,
    [MobileHomeTotalMileage]        INT             NULL,
    [MobileHomeEstCostPerMile]      NUMERIC (18, 2) NULL,
    [MobileHomeSubtotal]            NUMERIC (18, 2) NULL,
    [MEAHasSpouse]                  BIT             NULL,
    [MEACivilian]                   NUMERIC (18, 2) NULL,
    [MEACivilianAndSpouse]          NUMERIC (18, 2) NULL,
    [MEASubtotal]                   NUMERIC (18, 2) NULL,
    [RealEstateOrLease]             VARCHAR (25)    NULL,
    [SalePriceAmount]               NUMERIC (18, 2) NULL,
    [PurchasePriceAmount]           NUMERIC (18, 2) NULL,
    [RealEstateSubtotal]            NUMERIC (18, 2) NULL,
    [UELAmount]                     NUMERIC (18, 2) NULL,
    [UELTotal]                      NUMERIC (18, 2) NULL,
    [RealEstateLeaseTotal]          NUMERIC (18, 2) NULL,
    [IsIsolatedDutyStation]         BIT             NULL,
    [NTSSubtotal]                   NUMERIC (18, 2) NULL,
    [DefaultFederalTaxRate]         NUMERIC (8, 4)  NULL,
    [FederalTaxRate]                NUMERIC (8, 4)  NULL,
    [HouseHuntingRITA]              NUMERIC (18, 2) NULL,
    [TransportationRITA]            NUMERIC (18, 2) NULL,
    [TQSERITA]                      NUMERIC (18, 2) NULL,
    [GHTransportationRITA]          NUMERIC (18, 2) NULL,
    [MEARITA]                       NUMERIC (18, 2) NULL,
    [RealEstateLeaseRITA]           NUMERIC (18, 2) NULL,
    [NTSRITA]                       NUMERIC (18, 2) NULL,
    [RITASubtotal]                  NUMERIC (18, 2) NULL,
    [GrandTotal]                    NUMERIC (18, 2) NULL,
    [StateTaxRate]                  NUMERIC (8, 4)  NULL,
    [SocialSecurityTaxRate]         NUMERIC (8, 4)  NULL,
    [MedicareTaxRate]               NUMERIC (8, 4)  NULL,
    [CountyTaxRate]                 NUMERIC (8, 4)  NULL,
    [CityTaxRate]                   NUMERIC (8, 4)  NULL,
    [TotalTaxRate]                  NUMERIC (8, 4)  NULL,
    [Deleted]                       BIT             CONSTRAINT [DF_PCSProject_Deleted] DEFAULT ((0)) NOT NULL,
    [SalePriceRefund]               NUMERIC (8, 4)  NULL,
    [PurchasePriceRefund]           NUMERIC (8, 4)  NULL,
    [TQSEDependents]                INT             NULL,
    [TransportationDependents]      INT             NULL,
    CONSTRAINT [PK_PCSProject] PRIMARY KEY CLUSTERED ([UserId] ASC, [ProjectName] ASC),
    CONSTRAINT [FK__PCSProject__DestinationId__Location] FOREIGN KEY ([DestinationId]) REFERENCES [warehouse].[Location] ([LocationId]),
    CONSTRAINT [FK__PCSProject__OriginationId__Location] FOREIGN KEY ([OriginationId]) REFERENCES [warehouse].[Location] ([LocationId]),
    CONSTRAINT [FK__PCSProject__UserId__AMCOSUser] FOREIGN KEY ([UserId]) REFERENCES [webuser].[AMCOSUser] ([UserId])
);




GO


GO


GO


GO


GO

