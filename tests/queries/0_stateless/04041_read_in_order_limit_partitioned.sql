-- optimize_read_in_order with LIMIT on a partitioned table: parts from partitions that cannot
-- contribute to the top-N are trimmed, so the merge fan-in is small (e.g. 5, the limit, not 20, the number of parts).

DROP TABLE IF EXISTS t_read_in_order_partitioned;

CREATE TABLE t_read_in_order_partitioned (dt DateTime, val UInt64)
ENGINE = MergeTree
PARTITION BY toYYYYMM(dt)
ORDER BY dt
SETTINGS index_granularity = 8192;

SYSTEM STOP MERGES t_read_in_order_partitioned;

-- 5 parts per month × 4 months = 20 parts (Jan=lowest dt, Apr=highest).
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-01-01 00:00:00') + number * 60, number        FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-01-01 03:00:00') + number * 60, number + 200  FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-01-01 06:00:00') + number * 60, number + 400  FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-01-01 09:00:00') + number * 60, number + 600  FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-01-01 12:00:00') + number * 60, number + 800  FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-02-01 00:00:00') + number * 60, number + 1000 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-02-01 03:00:00') + number * 60, number + 1200 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-02-01 06:00:00') + number * 60, number + 1400 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-02-01 09:00:00') + number * 60, number + 1600 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-02-01 12:00:00') + number * 60, number + 1800 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-03-01 00:00:00') + number * 60, number + 2000 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-03-01 03:00:00') + number * 60, number + 2200 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-03-01 06:00:00') + number * 60, number + 2400 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-03-01 09:00:00') + number * 60, number + 2600 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-03-01 12:00:00') + number * 60, number + 2800 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-04-01 00:00:00') + number * 60, number + 3000 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-04-01 03:00:00') + number * 60, number + 3200 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-04-01 06:00:00') + number * 60, number + 3400 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-04-01 09:00:00') + number * 60, number + 3600 FROM numbers(200);
INSERT INTO t_read_in_order_partitioned SELECT toDateTime('2024-04-01 12:00:00') + number * 60, number + 3800 FROM numbers(200);

-- Correctness Check: ascending order
SELECT val FROM t_read_in_order_partitioned ORDER BY dt ASC LIMIT 5
SETTINGS optimize_read_in_order = 1, max_threads = 2;
-- Correctness Check: descending order
SELECT val FROM t_read_in_order_partitioned ORDER BY dt DESC LIMIT 5
SETTINGS optimize_read_in_order = 1, max_threads = 2;

-- Pipeline (ascending): the MergingSortedTransform that merges part-level streams must have fan-in <= 5, not 20.
SELECT extract(trimLeft(explain), 'MergingSortedTransform (\\d+) → 1') AS fanin, toUInt64(fanin) <= 5 AS ok
FROM (
    EXPLAIN PIPELINE (
        SELECT val FROM t_read_in_order_partitioned ORDER BY dt ASC LIMIT 5
        SETTINGS optimize_read_in_order = 1, max_threads = 2
    )
) 
WHERE explain LIKE '%MergingSortedTransform%' LIMIT 1;

-- Pipeline (descending): same check (trimmed to April's 5 parts).
SELECT extract(trimLeft(explain), 'MergingSortedTransform (\\d+) → 1') AS fanin, toUInt64(fanin) <= 5 AS ok
FROM (
    EXPLAIN PIPELINE (
        SELECT val FROM t_read_in_order_partitioned ORDER BY dt DESC LIMIT 5
        SETTINGS optimize_read_in_order = 1, max_threads = 2
    )
) 
WHERE explain LIKE '%MergingSortedTransform%' LIMIT 1;

SYSTEM START MERGES t_read_in_order_partitioned;
DROP TABLE t_read_in_order_partitioned;
