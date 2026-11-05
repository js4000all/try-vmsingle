-- Large one-month synthetic dataset: 2026-10 UTC, half-open month interval.
-- 200 analogue metrics sampled every minute + 100 sparse ON/OFF metrics.
-- This file writes only to /workspace/layout-large/ (not to R2).
-- Before re-running, remove ONLY the generated Parquet files in layout-large.
SET TimeZone = 'UTC';

CREATE OR REPLACE TEMP VIEW large_long AS
WITH minutes AS (
    SELECT i, TIMESTAMPTZ '2026-10-01 00:00:00+00'
              + i * INTERVAL 1 MINUTE AS timestamp
    FROM range(44640) AS t(i)
),
analog AS (
    SELECT
        m.timestamp,
        printf('analog_%03d', s.sensor_id) AS metric,
        CAST(20.0 + s.sensor_id * 0.01
             + 3.0 * sin(m.i / 60.0 + s.sensor_id * 0.1) AS DOUBLE) AS value
    FROM minutes m
    CROSS JOIN range(1, 201) AS s(sensor_id)
),
signal AS (
    -- Each signal is recorded at UTC midnight (a daily refresh) and
    -- about once per week at a sensor-specific minute (state change).
    -- The reading value reflects a deterministic sequence of toggles.
    SELECT
        m.timestamp,
        printf('signal_%03d', s.sensor_id) AS metric,
        CAST(
            CASE WHEN m.i < 360 + s.sensor_id THEN 0
                 ELSE (1 + CAST(floor((m.i - 360 - s.sensor_id) / 10080.0) AS BIGINT)) % 2
            END AS DOUBLE
        ) AS value
    FROM minutes m
    CROSS JOIN range(1, 101) AS s(sensor_id)
    WHERE m.i % 1440 = 0
       OR m.i % 10080 = 360 + s.sensor_id
)
SELECT timestamp, metric, value FROM analog
UNION ALL
SELECT timestamp, metric, value FROM signal;

-- Both outputs originate from exactly the same view.
COPY (
    SELECT timestamp, metric, value FROM large_long
) TO '/workspace/layout-large/long-2026-10.parquet'
  (FORMAT PARQUET, COMPRESSION ZSTD);

-- Sparse metrics become nullable columns, while the timestamps
-- are shared with the densely sampled analogue metrics.
CREATE OR REPLACE TEMP TABLE large_wide AS
PIVOT large_long ON metric USING max(value) GROUP BY timestamp;

COPY large_wide TO '/workspace/layout-large/wide-2026-10.parquet'
  (FORMAT PARQUET, COMPRESSION ZSTD);

SELECT 'long_samples' AS measure, count(*) AS n
  FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
UNION ALL
SELECT 'wide_rows', count(*)
  FROM read_parquet('/workspace/layout-large/wide-2026-10.parquet');
