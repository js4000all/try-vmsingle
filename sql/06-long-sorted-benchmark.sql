-- Performance experiment on the same month of data.
-- Compare the TOTAL TIME for the three queries after warming the cache.
-- Alternate the order across repetitions to reduce cache/order bias.
SET TimeZone = 'UTC';

-- A: Wide, single column.
EXPLAIN ANALYZE
SELECT avg(analog_001)
FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet');

-- B: Original Long (metrics interleaved).
EXPLAIN ANALYZE
SELECT avg(value)
FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
WHERE metric = 'analog_001';

-- C: Long sorted by metric then timestamp.
EXPLAIN ANALYZE
SELECT avg(value)
FROM read_parquet('/workspace/layout-large/long-by-metric-2026-10.parquet')
WHERE metric = 'analog_001';

-- D: Filtered 1-hour range for the same metric; repeat across layouts.
EXPLAIN ANALYZE
SELECT avg(analog_001)
FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet')
WHERE timestamp >= TIMESTAMPTZ '2026-10-15 12:00:00+00'
  AND timestamp <  TIMESTAMPTZ '2026-10-15 13:00:00+00';

EXPLAIN ANALYZE
SELECT avg(value)
FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
WHERE metric = 'analog_001'
  AND timestamp >= TIMESTAMPTZ '2026-10-15 12:00:00+00'
  AND timestamp <  TIMESTAMPTZ '2026-10-15 13:00:00+00';

EXPLAIN ANALYZE
SELECT avg(value)
FROM read_parquet('/workspace/layout-large/long-by-metric-2026-10.parquet')
WHERE metric = 'analog_001'
  AND timestamp >= TIMESTAMPTZ '2026-10-15 12:00:00+00'
  AND timestamp <  TIMESTAMPTZ '2026-10-15 13:00:00+00';
