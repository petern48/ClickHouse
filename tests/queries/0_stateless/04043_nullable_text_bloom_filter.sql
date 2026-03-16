-- Tests that tokenbf_v1 and ngrambf_v1 indexes accept Nullable column types.
-- NULL values must be skipped during index construction and never produce false negatives.

DROP TABLE IF EXISTS t;

-- Nullable(String) with tokenbf_v1
CREATE TABLE t
(
    i UInt32,
    a Nullable(String),
    INDEX idx a TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello world'), (2, 'foo bar'), (3, NULL), (4, 'baz qux');

SELECT count() FROM t WHERE hasToken(a, 'hello');   -- 1
SELECT count() FROM t WHERE hasToken(a, 'foo');     -- 1
SELECT count() FROM t WHERE hasToken(a, 'missing'); -- 0
SELECT count() FROM t WHERE a IS NULL;              -- 1

DROP TABLE t;

-- Nullable(String) with ngrambf_v1
CREATE TABLE t
(
    i UInt32,
    a Nullable(String),
    INDEX idx a TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello'), (2, 'world'), (3, NULL), (4, 'foobar');

SELECT count() FROM t WHERE a LIKE '%hel%';  -- 1
SELECT count() FROM t WHERE a LIKE '%xyz%';  -- 0
SELECT count() FROM t WHERE a IS NULL;       -- 1

DROP TABLE t;

-- Nullable(FixedString) with tokenbf_v1 (index creation only; hasToken does not support FixedString)
CREATE TABLE t
(
    i UInt32,
    a Nullable(FixedString(20)),
    INDEX idx a TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello'), (2, NULL), (3, 'world');

SELECT count() FROM t WHERE a IS NULL;     -- 1
SELECT count() FROM t WHERE a IS NOT NULL; -- 2

DROP TABLE t;

-- Nullable(FixedString) with ngrambf_v1
CREATE TABLE t
(
    i UInt32,
    a Nullable(FixedString(20)),
    INDEX idx a TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello'), (2, NULL), (3, 'world');

SELECT count() FROM t WHERE a LIKE '%hel%';  -- 1
SELECT count() FROM t WHERE a LIKE '%xyz%';  -- 0
SELECT count() FROM t WHERE a IS NULL;       -- 1

DROP TABLE t;

-- LowCardinality(Nullable(String)) with tokenbf_v1
CREATE TABLE t
(
    i UInt32,
    a LowCardinality(Nullable(String)),
    INDEX idx a TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello world'), (2, 'foo bar'), (3, NULL), (4, 'baz qux');

SELECT count() FROM t WHERE hasToken(a, 'hello');   -- 1
SELECT count() FROM t WHERE hasToken(a, 'foo');     -- 1
SELECT count() FROM t WHERE hasToken(a, 'missing'); -- 0
SELECT count() FROM t WHERE a IS NULL;              -- 1

DROP TABLE t;

-- LowCardinality(Nullable(String)) with ngrambf_v1
CREATE TABLE t
(
    i UInt32,
    a LowCardinality(Nullable(String)),
    INDEX idx a TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello'), (2, 'world'), (3, NULL), (4, 'foobar');

SELECT count() FROM t WHERE a LIKE '%hel%';  -- 1
SELECT count() FROM t WHERE a LIKE '%xyz%';  -- 0
SELECT count() FROM t WHERE a IS NULL;       -- 1

DROP TABLE t;

-- LowCardinality(Nullable(FixedString)) with ngrambf_v1
CREATE TABLE t
(
    i UInt32,
    a LowCardinality(Nullable(FixedString(20))),
    INDEX idx a TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, 'hello'), (2, NULL), (3, 'world');

SELECT count() FROM t WHERE a LIKE '%hel%';  -- 1
SELECT count() FROM t WHERE a LIKE '%xyz%';  -- 0
SELECT count() FROM t WHERE a IS NULL;       -- 1

DROP TABLE t;

-- Array(Nullable(String)) with tokenbf_v1
CREATE TABLE t
(
    i UInt32,
    a Array(Nullable(String)),
    INDEX idx a TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

INSERT INTO t VALUES (1, ['hello', 'world']), (2, [NULL, 'foo']), (3, []);

SELECT count() FROM t WHERE hasTokenOrNull(a[1], 'hello');   -- 1
SELECT count() FROM t WHERE hasTokenOrNull(a[1], 'missing'); -- 0

DROP TABLE t;

-- ALTER TABLE path: add indexes to existing Nullable(String) and Nullable(FixedString) columns
CREATE TABLE t
(
    i UInt32,
    a Nullable(String),
    b Nullable(FixedString(20))
)
ENGINE = MergeTree ORDER BY i SETTINGS index_granularity = 1;

ALTER TABLE t ADD INDEX idx_a_tok  a TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1;
ALTER TABLE t ADD INDEX idx_a_ngr  a TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1;
ALTER TABLE t ADD INDEX idx_b_tok  b TYPE tokenbf_v1(512, 3, 0) GRANULARITY 1;
ALTER TABLE t ADD INDEX idx_b_ngr  b TYPE ngrambf_v1(3, 512, 3, 0) GRANULARITY 1;

DROP TABLE t;
