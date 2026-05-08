
-- ─────────────────────────────────────────────────────────────────────────────
-- iceberg.demo.sql  –  Iceberg MERGE INTO demo
-- Uses three-part identifiers (catalog.namespace.table) throughout so the
-- REST catalog always receives a valid namespace.table pair.
-- ─────────────────────────────────────────────────────────────────────────────
SHOW CATALOGS;
show databases;
select current_schema();

USE demo;
SET `spark.sql.catalog.iceberg.default-namespace`=`demo`;

-- ─── Reset ───────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS iceberg.demo.target_table;
DROP TABLE IF EXISTS iceberg.demo.source_table;

-- ─── Create tables ───────────────────────────────────────────────────────────
CREATE TABLE iceberg.demo.target_table (
  id        INT,
  name      STRING,
  amount    INT,
  update_ts TIMESTAMP
) USING iceberg;

CREATE TABLE iceberg.demo.source_table (
  id        INT,
  name      STRING,
  amount    INT,
  update_ts TIMESTAMP
) USING iceberg;

-- ─── Seed target ─────────────────────────────────────────────────────────────
INSERT INTO iceberg.demo.target_table VALUES
  (1, 'Alice',   100, CAST('2026-05-01 10:00:00' AS TIMESTAMP)),
  (2, 'Bob',     200, CAST('2026-05-01 10:00:00' AS TIMESTAMP)),
  (3, 'Charlie', 300, CAST('2026-05-01 10:00:00' AS TIMESTAMP));

SELECT 'target after initial seed' AS stage, * FROM iceberg.demo.target_table ORDER BY id;

-- ─── Seed source round 1 ─────────────────────────────────────────────────────
INSERT INTO iceberg.demo.source_table VALUES
  (3, 'Charlie', 300, CAST('2026-04-30 09:00:00' AS TIMESTAMP)),
  (4, 'David',   400, CAST('2026-05-02 12:00:00' AS TIMESTAMP));

SELECT 'source round 1' AS stage, * FROM iceberg.demo.source_table ORDER BY id;

-- ─── MERGE round 1 ───────────────────────────────────────────────────────────
MERGE INTO iceberg.demo.target_table t
USING iceberg.demo.source_table s
ON t.id = s.id
WHEN MATCHED AND s.update_ts > t.update_ts THEN
  UPDATE SET
    t.name      = s.name,
    t.amount    = s.amount,
    t.update_ts = s.update_ts
WHEN NOT MATCHED THEN
  INSERT (id, name, amount, update_ts)
  VALUES (s.id, s.name, s.amount, s.update_ts);

SELECT 'target after MERGE round 1' AS stage, * FROM iceberg.demo.target_table ORDER BY id;

-- ─── Source update round 2 ───────────────────────────────────────────────────
INSERT INTO iceberg.demo.source_table VALUES
  (1, 'Alice', 150, CAST('2026-05-03 09:00:00' AS TIMESTAMP));

-- ─── MERGE round 2 ───────────────────────────────────────────────────────────
MERGE INTO iceberg.demo.target_table t
USING iceberg.demo.source_table s
ON t.id = s.id
WHEN MATCHED AND s.update_ts > t.update_ts THEN
  UPDATE SET
    t.name      = s.name,
    t.amount    = s.amount,
    t.update_ts = s.update_ts
WHEN NOT MATCHED THEN
  INSERT (id, name, amount, update_ts)
  VALUES (s.id, s.name, s.amount, s.update_ts);

SELECT 'target after MERGE round 2' AS stage, * FROM iceberg.demo.target_table ORDER BY id;


-- ─── Iceberg metadata tables ─────────────────────────────────────────────────
SELECT 'source_table.files'          AS metadata_view, * FROM iceberg.demo.source_table.files;
SELECT 'source_table.snapshots'      AS metadata_view, * FROM iceberg.demo.source_table.snapshots;
SELECT 'target_table.files'          AS metadata_view, * FROM iceberg.demo.target_table.files;
SELECT 'target_table.snapshots'      AS metadata_view, * FROM iceberg.demo.target_table.snapshots;
SELECT 'target_table.all_data_files' AS metadata_view, * FROM iceberg.demo.target_table.all_data_files;