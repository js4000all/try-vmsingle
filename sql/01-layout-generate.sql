-- Synthetic data, independent of the Archiver.
-- Run with: .read /workspace/sql/01-layout-generate.sql
-- Output: /workspace/layout-test (existing directory)
SET TimeZone = 'UTC';

CREATE OR REPLACE TEMP TABLE layout_long AS
WITH minutes AS (
  SELECT i, TIMESTAMPTZ '2026-09-30 00:00:00+00' + i * INTERVAL 1 MINUTE AS ts
  FROM range(2880) t(i)
), sensors AS (
  SELECT '001' AS site_id, '1' AS sensor_id, 1 AS series_no, 1 AS interval_min
  UNION ALL SELECT '001', '2', 2, 2
  UNION ALL SELECT '002', '1', 3, 5
  UNION ALL SELECT '002', '2', 4, 60
)
SELECT
  m.ts AS timestamp,
  s.site_id,
  s.sensor_id,
  CAST(20.0 + s.series_no + 3.0 * sin(m.i / 60.0) AS DOUBLE) AS value
FROM minutes m CROSS JOIN sensors s
WHERE m.i % s.interval_min = 0;

-- The four sensors have different timestamps, so the wide representation
-- contains NULLs for sensors that did not emit a sample.
CREATE OR REPLACE TEMP TABLE layout_wide AS
SELECT
  timestamp,
  max(value) FILTER (WHERE site_id = '001' AND sensor_id = '1') AS site001_sensor1,
  max(value) FILTER (WHERE site_id = '001' AND sensor_id = '2') AS site001_sensor2,
  max(value) FILTER (WHERE site_id = '002' AND sensor_id = '1') AS site002_sensor1,
  max(value) FILTER (WHERE site_id = '002' AND sensor_id = '2') AS site002_sensor2
FROM layout_long
GROUP BY timestamp;

-- Two monthly Parquet files; half-open UTC month boundaries.
COPY (SELECT * FROM layout_long
      WHERE timestamp >= TIMESTAMPTZ '2026-09-01 00:00:00+00'
        AND timestamp < TIMESTAMPTZ '2026-10-01 00:00:00+00')
TO '/workspace/layout-test/long/2026-09.parquet' (FORMAT PARQUET);

-- Add a column in October to test schema evolution.
COPY (SELECT *, 'ok'::VARCHAR AS quality FROM layout_long
      WHERE timestamp >= TIMESTAMPTZ '2026-10-01 00:00:00+00'
        AND timestamp < TIMESTAMPTZ '2026-11-01 00:00:00+00')
TO '/workspace/layout-test/long/2026-10.parquet' (FORMAT PARQUET);

COPY (SELECT * FROM layout_wide
      WHERE timestamp >= TIMESTAMPTZ '2026-09-01 00:00:00+00'
        AND timestamp < TIMESTAMPTZ '2026-10-01 00:00:00+00')
TO '/workspace/layout-test/wide/2026-09.parquet' (FORMAT PARQUET);

COPY (SELECT * FROM layout_wide
      WHERE timestamp >= TIMESTAMPTZ '2026-10-01 00:00:00+00'
        AND timestamp < TIMESTAMPTZ '2026-11-01 00:00:00+00')
TO '/workspace/layout-test/wide/2026-10.parquet' (FORMAT PARQUET);

-- Hive year/month partitioning; no timestamps or series are real PLC data.
COPY (
  SELECT *, year(timestamp) AS year, month(timestamp) AS month
  FROM layout_long
)
TO '/workspace/layout-test/hive' (
  FORMAT PARQUET, PARTITION_BY (year, month)
);

SELECT 'long_samples' AS measure, count(*) AS n FROM layout_long
UNION ALL
SELECT 'wide_rows', count(*) FROM layout_wide;
