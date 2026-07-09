-- analysis.crunchtime — per-object runtime log written by crunch.CrunchAll (Phase 4).
-- Source: AMCOS.AMCOS2020_MAR/analysis/Tables/CrunchTime.sql.
CREATE TABLE IF NOT EXISTS analysis.crunchtime (
    objectname     varchar(75) NOT NULL,
    amcosversionid integer     NOT NULL,
    starttime      timestamp   NOT NULL,
    endtime        timestamp   NOT NULL,
    debug          boolean     DEFAULT false NOT NULL
);
