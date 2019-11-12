CREATE TABLE IF NOT EXISTS dagops_makefiles
(       UNIQ            INT             unsigned        NOT NULL,
        RUN_ID          INT             unsigned        NOT NULL,
        LINE            INT             unsigned        NOT NULL,
        PARENT          text                            NOT NULL,
        CHILD           text                            NOT NULL,
        COMMAND         TEXT    ) ;
