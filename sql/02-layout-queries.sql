-- Run after 01-layout-generate.sql, in the same or a later CLI session.
SET TimeZone = 'UTC';

-- 1. Multi-file wide scan, with explicit UTC boundaries.
SELECT count(*) AS wide_rows, count(site002_sensor2) AS sensor4_samples
FROM read_parquet('/workspace/layout-test/wide/*.parquet')
WHERE timestamp >= TIMESTAMPTZ '2026-09-30 00:00:00+00'
  AND timestamp < TIMESTAMPTZ '2026-10-02 00:00:00+00';

-- 2. Schema evolution: October adds "quality"; September yields NULL.
-- union_by_name merges columns that have different schemas.
SELECT date_trunc('month', timestamp) AS utc_month,
       count(*) AS samples,
       count(quality) AS with_quality
FROM read_parquet('/workspace/layout-test/long/*.parquet', union_by_name = true)
GROUP BY 1 ORDER BY 1;

-- 3. Hive partition pruning, and partition columns from directory names.
SELECT year, month, count(*) AS samples
FROM read_parquet('/workspace/layout-test/hive/*/*/*.parquet', hive_partitioning = true)
WHERE year = 2026 AND month = 10
GROUP BY year, month;

-- 4. Long -> wide, to compare with the stored wide format.
SELECT timestamp,
       max(value) FILTER (WHERE site_id='001' AND sensor_id='1') AS site001_sensor1,
       max(value) FILTER (WHERE site_id='002' AND sensor_id='2') AS site002_sensor2
FROM read_parquet('/workspace/layout-test/long/*.parquet', union_by_name=true)
WHERE timestamp >= TIMESTAMPTZ '2026-10-01 00:00:00+00'
  AND timestamp < TIMESTAMPTZ '2026-10-01 00:05:00+00'
GROUP BY timestamp ORDER BY timestamp;

-- 5. Investigate actual IO and filters by running manually:
-- EXPLAIN ANALYZE SELECT count(*) FROM read_parquet(
--   '/workspace/layout-test/hive/*/*/*.parquet', hive_partitioning=true
-- ) WHERE year=2026 AND month=10;
