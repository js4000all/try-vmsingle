-- Reorder existing Long Parquet by metric, then timestamp.
-- This does not regenerate samples or modify existing Parquet files.
-- Uses the same ZSTD compression and default row-group settings as the original.
SET TimeZone = 'UTC';

COPY (
    SELECT timestamp, metric, value
    FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
    ORDER BY metric, timestamp
)
TO '/workspace/layout-large/long-by-metric-2026-10.parquet'
(FORMAT PARQUET, COMPRESSION ZSTD);

-- Both representations must have the same total count.
SELECT 'original_long' AS layout, count(*) AS samples
FROM read_parquet('/workspace/layout-large/long-2026-10.parquet')
UNION ALL
SELECT 'sorted_long', count(*)
FROM read_parquet('/workspace/layout-large/long-by-metric-2026-10.parquet');

-- Check the physical order and values of the first records.
SELECT metric, timestamp, value
FROM read_parquet('/workspace/layout-large/long-by-metric-2026-10.parquet')
LIMIT 5;

-- Compare Parquet row-group metadata: number of groups and compressed bytes.
SELECT regexp_extract(file_name, '[^/]+$') AS file,
       count(DISTINCT row_group_id) AS row_groups,
       sum(total_compressed_size) AS column_chunk_bytes
FROM parquet_metadata([
  '/workspace/layout-large/long-2026-10.parquet',
  '/workspace/layout-large/long-by-metric-2026-10.parquet'
])
GROUP BY file_name ORDER BY file;
