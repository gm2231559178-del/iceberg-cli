
-- ─────────────────────────────────────────────────────────────────────────────
-- demo.sql  –  Iceberg MERGE INTO demo
-- Uses three-part identifiers (catalog.namespace.table) throughout so the
-- REST catalog always receives a valid namespace.table pair.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE NAMESPACE IF NOT EXISTS core.core;
use core.core;
show databases;
show tables;
select current_schema();
-- ─── Reset ───────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS core.core.target_table;
DROP TABLE IF EXISTS core.core.source_table;

-- ─── Create tables ───────────────────────────────────────────────────────────
CREATE TABLE core.core.target_table (
  id        INT,
  name      STRING,
  amount    INT,
  update_ts TIMESTAMP
) USING iceberg;

CREATE TABLE core.core.source_table (
  id        INT,
  name      STRING,
  amount    INT,
  update_ts TIMESTAMP
) USING iceberg;

-- ─── Seed target ─────────────────────────────────────────────────────────────
INSERT INTO core.core.target_table VALUES
  (1, 'Alice',   100, CAST('2026-05-01 10:00:00' AS TIMESTAMP)),
  (2, 'Bob',     200, CAST('2026-05-01 10:00:00' AS TIMESTAMP)),
  (3, 'Charlie', 300, CAST('2026-05-01 10:00:00' AS TIMESTAMP));

SELECT 'target after initial seed' AS stage, * FROM core.core.target_table ORDER BY id;

-- ─── Seed source round 1 ─────────────────────────────────────────────────────
INSERT INTO core.core.source_table VALUES
  (3, 'Charlie', 300, CAST('2026-04-30 09:00:00' AS TIMESTAMP)),
  (4, 'David',   400, CAST('2026-05-02 12:00:00' AS TIMESTAMP));

SELECT 'source round 1' AS stage, * FROM core.core.source_table ORDER BY id;

-- ─── MERGE round 1 ───────────────────────────────────────────────────────────
MERGE INTO core.core.target_table t
USING core.core.source_table s
ON t.id = s.id
WHEN MATCHED AND s.update_ts > t.update_ts THEN
  UPDATE SET
    t.name      = s.name,
    t.amount    = s.amount,
    t.update_ts = s.update_ts
WHEN NOT MATCHED THEN
  INSERT (id, name, amount, update_ts)
  VALUES (s.id, s.name, s.amount, s.update_ts);

SELECT 'target after MERGE round 1' AS stage, * FROM core.core.target_table ORDER BY id;

-- ─── Source update round 2 ───────────────────────────────────────────────────
INSERT INTO core.core.source_table VALUES
  (1, 'Alice', 150, CAST('2026-05-03 09:00:00' AS TIMESTAMP));

-- ─── MERGE round 2 ───────────────────────────────────────────────────────────
MERGE INTO core.core.target_table t
USING core.core.source_table s
ON t.id = s.id
WHEN MATCHED AND s.update_ts > t.update_ts THEN
  UPDATE SET
    t.name      = s.name,
    t.amount    = s.amount,
    t.update_ts = s.update_ts
WHEN NOT MATCHED THEN
  INSERT (id, name, amount, update_ts)
  VALUES (s.id, s.name, s.amount, s.update_ts);

SELECT 'target after MERGE round 2' AS stage, * FROM core.core.target_table ORDER BY id;

-- USE core.core;
-- SET `spark.sql.catalog.core.default-namespace`=`core`;

-- -- ─── Iceberg metadata tables ─────────────────────────────────────────────────
-- SELECT 'source_table.files'          AS metadata_view, * FROM core.source_table.files;
-- SELECT 'source_table.snapshots'      AS metadata_view, * FROM core.source_table.snapshots;
-- SELECT 'target_table.files'          AS metadata_view, * FROM core.target_table.files;
-- SELECT 'target_table.snapshots'      AS metadata_view, * FROM core.target_table.snapshots;
-- SELECT 'target_table.all_data_files' AS metadata_view, * FROM core.target_table.all_data_files;