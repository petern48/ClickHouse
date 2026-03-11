-- Test that filter pushdown works through JOIN USING when the key types differ.
-- Regression test: with enable_analyzer=1, the WHERE filter should be pushed to both sides.

DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;

CREATE TABLE t_left (a UInt32) ENGINE = MergeTree ORDER BY a;
CREATE TABLE t_right (a UInt64) ENGINE = MergeTree ORDER BY a;

INSERT INTO t_left SELECT number FROM numbers(1000);
INSERT INTO t_right SELECT number FROM numbers(1000);

-- Verify that the filter is pushed to both sides: EXPLAIN should have 2 Filter steps.
SELECT countIf(explain LIKE '%Filter%') >= 2
FROM (
    EXPLAIN SELECT a FROM t_left INNER JOIN t_right USING(a) WHERE a >= 700 AND a <= 800
    SETTINGS enable_analyzer=1, query_plan_use_new_logical_join_step=1
);

-- Verify correctness: result should contain values 700..800 (101 rows)
SELECT count() FROM t_left INNER JOIN t_right USING(a) WHERE a >= 700 AND a <= 800
SETTINGS enable_analyzer=1, query_plan_use_new_logical_join_step=1;

-- Test with reversed type order: left UInt64, right UInt32
DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;

CREATE TABLE t_left (a UInt64) ENGINE = MergeTree ORDER BY a;
CREATE TABLE t_right (a UInt32) ENGINE = MergeTree ORDER BY a;

INSERT INTO t_left SELECT number FROM numbers(1000);
INSERT INTO t_right SELECT number FROM numbers(1000);

SELECT count() FROM t_left INNER JOIN t_right USING(a) WHERE a >= 700 AND a <= 800
SETTINGS enable_analyzer=1, query_plan_use_new_logical_join_step=1;

DROP TABLE t_left;
DROP TABLE t_right;
