CREATE TABLE [lookup].[WeaponSystem] (
    [WeaponSystemId]      INT           IDENTITY (-1, 1) NOT NULL,
    [WeaponSystemName]    NVARCHAR (50) NULL,
    [AmcosVersionIdStart] INT           NULL,
    [AmcosVersionIdEnd]   INT           NOT NULL,
    CONSTRAINT [PK_WeaponSystem] PRIMARY KEY CLUSTERED ([WeaponSystemId] ASC, [AmcosVersionIdEnd] ASC)
);



