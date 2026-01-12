/* ============================================================
   MIND (small) ? ONLY ml_train_shown + ml_dev_shown
   SQL Server 2022 (compat level 160)
   Keeps impressions that have >= 1 click, and includes BOTH
   clicked + unclicked rows inside those impressions.
   ============================================================ */

USE [Koelsch MIND Project];
GO

/* --- Optional sanity check: do files exist? --- */
EXEC master..xp_fileexist "C:\Users\ckoel\Downloads\MIND_test\MIND_train\news_train.tsv";
EXEC master..xp_fileexist "C:\Users\ckoel\Downloads\MIND_test\MIND_train\behaviors_train.tsv";
EXEC master..xp_fileexist "C:\Users\ckoel\Downloads\MIND_dev\news_dev.tsv";
EXEC master..xp_fileexist "C:\Users\ckoel\Downloads\MIND_dev\behaviors_dev.tsv";
GO

/* ============================================================
   1) RAW TABLES + BULK LOAD
   ============================================================ */
DROP TABLE IF EXISTS dbo.news_train_raw;
DROP TABLE IF EXISTS dbo.news_dev_raw;
DROP TABLE IF EXISTS dbo.behaviors_train_raw;
DROP TABLE IF EXISTS dbo.behaviors_dev_raw;
GO

CREATE TABLE dbo.news_train_raw (
    news_id           VARCHAR(20)     NULL,
    category          VARCHAR(50)     NULL,
    subcategory       VARCHAR(50)     NULL,
    title             NVARCHAR(500)   NULL,
    abstract          NVARCHAR(MAX)   NULL,
    url               NVARCHAR(2048)  NULL,
    title_entities    NVARCHAR(MAX)   NULL,
    abstract_entities NVARCHAR(MAX)   NULL
);

CREATE TABLE dbo.news_dev_raw (
    news_id           VARCHAR(20)     NULL,
    category          VARCHAR(50)     NULL,
    subcategory       VARCHAR(50)     NULL,
    title             NVARCHAR(500)   NULL,
    abstract          NVARCHAR(MAX)   NULL,
    url               NVARCHAR(2048)  NULL,
    title_entities    NVARCHAR(MAX)   NULL,
    abstract_entities NVARCHAR(MAX)   NULL
);

CREATE TABLE dbo.behaviors_train_raw (
    impression_id     INT           NULL,
    user_id           VARCHAR(30)   NULL,
    impression_time   NVARCHAR(30)  NULL,
    history           NVARCHAR(MAX) NULL,
    impressions       NVARCHAR(MAX) NULL
);

CREATE TABLE dbo.behaviors_dev_raw (
    impression_id     INT           NULL,
    user_id           VARCHAR(30)   NULL,
    impression_time   NVARCHAR(30)  NULL,
    history           NVARCHAR(MAX) NULL,
    impressions       NVARCHAR(MAX) NULL
);
GO

BULK INSERT dbo.news_train_raw
FROM "C:\Users\ckoel\Downloads\MIND_test\MIND_train\news_train.tsv"
WITH (
  FIELDTERMINATOR = '\t',
  ROWTERMINATOR   = '0x0a',
  CODEPAGE        = '65001',
  TABLOCK
);

BULK INSERT dbo.behaviors_train_raw
FROM "C:\Users\ckoel\Downloads\MIND_test\MIND_train\behaviors_train.tsv"
WITH (
  FIELDTERMINATOR = '\t',
  ROWTERMINATOR   = '0x0a',
  CODEPAGE        = '65001',
  TABLOCK
);

BULK INSERT dbo.news_dev_raw
FROM "C:\Users\ckoel\Downloads\MIND_dev\news_dev.tsv"
WITH (
  FIELDTERMINATOR = '\t',
  ROWTERMINATOR   = '0x0a',
  CODEPAGE        = '65001',
  TABLOCK
);

BULK INSERT dbo.behaviors_dev_raw
FROM "C:\Users\ckoel\Downloads\MIND_dev\behaviors_dev.tsv"
WITH (
  FIELDTERMINATOR = '\t',
  ROWTERMINATOR   = '0x0a',
  CODEPAGE        = '65001',
  TABLOCK
);
GO

/* ============================================================
   2) NEWS DIM (union train+dev)
   ============================================================ */
DROP TABLE IF EXISTS dbo.news_dim;
GO

SELECT DISTINCT
    news_id,
    category,
    subcategory,
    title,
    abstract,
    url,
    title_entities,
    abstract_entities
INTO dbo.news_dim
FROM dbo.news_train_raw

UNION

SELECT DISTINCT
    news_id,
    category,
    subcategory,
    title,
    abstract,
    url,
    title_entities,
    abstract_entities
FROM dbo.news_dev_raw;
GO

CREATE UNIQUE CLUSTERED INDEX CX_news_dim ON dbo.news_dim(news_id);
GO

/* ============================================================
   3) IMPRESSION ITEMS (shown candidates with clicked label)
      NOTE: ordering/position not needed, so we don’t store it.
   ============================================================ */
DROP TABLE IF EXISTS dbo.impression_item_train;
DROP TABLE IF EXISTS dbo.impression_item_dev;
GO

CREATE TABLE dbo.impression_item_train (
    impression_id INT         NOT NULL,
    news_id       VARCHAR(20) NOT NULL,
    clicked       BIT         NOT NULL,
    CONSTRAINT PK_impression_item_train PRIMARY KEY CLUSTERED (impression_id, news_id)
);

CREATE TABLE dbo.impression_item_dev (
    impression_id INT         NOT NULL,
    news_id       VARCHAR(20) NOT NULL,
    clicked       BIT         NOT NULL,
    CONSTRAINT PK_impression_item_dev PRIMARY KEY CLUSTERED (impression_id, news_id)
);
GO

/* Train */
INSERT INTO dbo.impression_item_train (impression_id, news_id, clicked)
SELECT DISTINCT
    b.impression_id,
    LEFT(tok.value, CHARINDEX('-', tok.value) - 1) AS news_id,
    CASE RIGHT(tok.value, 1)
        WHEN '1' THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS clicked
FROM dbo.behaviors_train_raw b
CROSS APPLY (
    SELECT LTRIM(RTRIM(value)) AS value
    FROM STRING_SPLIT(b.impressions, ' ')
) tok
WHERE b.impression_id IS NOT NULL
  AND b.impressions IS NOT NULL
  AND LTRIM(RTRIM(b.impressions)) <> ''
  AND tok.value <> ''
  AND CHARINDEX('-', tok.value) > 1;   -- ensures LEFT(.., idx-1) is valid
GO

/* Dev */
INSERT INTO dbo.impression_item_dev (impression_id, news_id, clicked)
SELECT DISTINCT
    b.impression_id,
    LEFT(tok.value, CHARINDEX('-', tok.value) - 1) AS news_id,
    CASE RIGHT(tok.value, 1)
        WHEN '1' THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS clicked
FROM dbo.behaviors_dev_raw b
CROSS APPLY (
    SELECT LTRIM(RTRIM(value)) AS value
    FROM STRING_SPLIT(b.impressions, ' ')
) tok
WHERE b.impression_id IS NOT NULL
  AND b.impressions IS NOT NULL
  AND LTRIM(RTRIM(b.impressions)) <> ''
  AND tok.value <> ''
  AND CHARINDEX('-', tok.value) > 1;
GO

/* Helpful indexes (fast "has-click" EXISTS + pop stats) */
BEGIN TRY
    CREATE INDEX IX_item_train_clicked_imp
    ON dbo.impression_item_train(impression_id)
    WHERE clicked = 1;
END TRY BEGIN CATCH END CATCH;

BEGIN TRY
    CREATE INDEX IX_item_dev_clicked_imp
    ON dbo.impression_item_dev(impression_id)
    WHERE clicked = 1;
END TRY BEGIN CATCH END CATCH;

CREATE INDEX IX_item_train_news ON dbo.impression_item_train(news_id) INCLUDE (clicked);
GO

/* ============================================================
   4) GLOBAL POPULARITY (train-only)
   ============================================================ */
DROP TABLE IF EXISTS dbo.news_pop_train;
GO

SELECT
    news_id,
    COUNT_BIG(*) AS shown_cnt,
    SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS click_cnt,
    CAST(SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS float) / NULLIF(COUNT_BIG(*), 0) AS ctr
INTO dbo.news_pop_train
FROM dbo.impression_item_train
GROUP BY news_id;
GO

CREATE UNIQUE CLUSTERED INDEX CX_news_pop_train ON dbo.news_pop_train(news_id);
GO

/* ============================================================
   5) FINAL ML TABLES (ONLY)
      Keep impressions with >=1 click, include all shown rows.
   ============================================================ */
DROP TABLE IF EXISTS dbo.ml_train_shown;
DROP TABLE IF EXISTS dbo.ml_dev_shown;
GO

/* Train ML shown */
SELECT
    it.impression_id,
    CAST(it.clicked AS tinyint) AS clicked,
    it.news_id,
    COALESCE(p.ctr, 0.0)       AS global_ctr,
    COALESCE(p.shown_cnt, 0)   AS global_shown_cnt,
    COALESCE(p.click_cnt, 0)   AS global_click_cnt,
    n.category,
    n.subcategory,
    LEN(COALESCE(n.title, N''))    AS title_len,
    LEN(COALESCE(n.abstract, N'')) AS abstract_len
INTO dbo.ml_train_shown
FROM dbo.impression_item_train it
LEFT JOIN dbo.news_pop_train p
  ON p.news_id = it.news_id
LEFT JOIN dbo.news_dim n
  ON n.news_id = it.news_id
WHERE EXISTS (
    SELECT 1
    FROM dbo.impression_item_train it2
    WHERE it2.impression_id = it.impression_id
      AND it2.clicked = 1
);
GO

CREATE INDEX IX_ml_train_shown_imp ON dbo.ml_train_shown(impression_id);
GO

/* Dev ML shown */
SELECT
    it.impression_id,
    CAST(it.clicked AS tinyint) AS clicked,
    it.news_id,
    COALESCE(p.ctr, 0.0)       AS global_ctr,
    COALESCE(p.shown_cnt, 0)   AS global_shown_cnt,
    COALESCE(p.click_cnt, 0)   AS global_click_cnt,
    n.category,
    n.subcategory,
    LEN(COALESCE(n.title, N''))    AS title_len,
    LEN(COALESCE(n.abstract, N'')) AS abstract_len
INTO dbo.ml_dev_shown
FROM dbo.impression_item_dev it
LEFT JOIN dbo.news_pop_train p
  ON p.news_id = it.news_id
LEFT JOIN dbo.news_dim n
  ON n.news_id = it.news_id
WHERE EXISTS (
    SELECT 1
    FROM dbo.impression_item_dev it2
    WHERE it2.impression_id = it.impression_id
      AND it2.clicked = 1
);
GO

CREATE INDEX IX_ml_dev_shown_imp ON dbo.ml_dev_shown(impression_id);
GO

/* ============================================================
   Quick checks
   ============================================================ */
SELECT TOP (100) * FROM dbo.ml_train_shown;
SELECT TOP (100) * FROM dbo.ml_dev_shown;

