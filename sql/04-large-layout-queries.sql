-- Run after 03-large-layout-generate.sql
SET TimeZone = 'UTC';

-- Expected:
-- 200 * 44,640 = 8,928,000 analogue samples.
-- 100 * 31 daily refreshes + ~4 or 5 weekly changes per signal.
-- Therefore Long is slightly above 8.93 million records.
-- Wide contains 44,640 rows with 300 series columns plus timestamp.
SELECT
    regexp_extract(metric, '^[^_]+') AS kind,
    count(*) AS samples,
    count(DISTINCT metric) AS series
FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
GROUP BY 1 ORDER BY 1;

SELECT count(*) AS rows,
       count(analog_001) AS analog_samples,
       count(signal_001) AS signal_samples,
       count(signal_100) AS signal100_samples
FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet');

SELECT count(*) AS total_columns
FROM parquet_schema('/workspace/layout-large/wide-2026-10.parquet')
WHERE name <> 'schema';

-- Spot-check: sparse signal is NULL between recorded events, NOT carried forward.
SELECT timestamp, analog_001, signal_001
FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet')
WHERE timestamp >= TIMESTAMPTZ '2026-10-01 00:00:00+00'
  AND timestamp < TIMESTAMPTZ '2026-10-01 00:04:00+00'
ORDER BY timestamp;

-- Aggregation workloads, for ad hoc comparison; use EXPLAIN ANALYZE separately.
SELECT avg(analog_001) AS avg_analog_001
FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet');

SELECT avg(value) AS avg_analog_001
FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
WHERE metric = 'analog_001';
