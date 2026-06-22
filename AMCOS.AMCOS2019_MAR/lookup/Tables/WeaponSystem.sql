CREATE TABLE [lookup].[WeaponSystem] (
    [WeaponSystemId]   INT           IDENTITY (-1, 1) NOT NULL,
    [WeaponSystemName] NVARCHAR (50) NULL,
    CONSTRAINT [PK_WeaponSystem] PRIMARY KEY CLUSTERED ([WeaponSystemId] ASC)
);

