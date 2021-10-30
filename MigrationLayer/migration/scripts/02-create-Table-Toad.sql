CREATE TABLE Toad
(
    [Id]   [bigint] IDENTITY (1,1) NOT NULL,
    [Text] [nvarchar](255)         NOT NULL,
    CONSTRAINT [PK_Toad] PRIMARY KEY   CLUSTERED ([Id])
);