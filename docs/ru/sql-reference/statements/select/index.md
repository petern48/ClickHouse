---
slug: /ru/sql-reference/statements/select/
title: "Синтаксис запросов SELECT"
sidebar_label: SELECT
sidebar_position: 32
---

# Синтаксис запросов SELECT {#select-queries-syntax}

`SELECT` выполняет получение данных.

``` sql
[WITH expr_list|(subquery)]
SELECT [DISTINCT [ON (column1, column2, ...)]] expr_list
[FROM [db.]table | (subquery) | table_function] [FINAL]
[SAMPLE sample_coeff]
[ARRAY JOIN ...]
[GLOBAL] [ANY|ALL|ASOF] [INNER|LEFT|RIGHT|FULL|CROSS] [OUTER|SEMI|ANTI] JOIN (subquery)|table (ON <expr_list>)|(USING <column_list>)
[PREWHERE expr]
[WHERE expr]
[GROUP BY expr_list] [WITH ROLLUP|WITH CUBE] [WITH TOTALS]
[HAVING expr]
[ORDER BY expr_list] [WITH FILL] [FROM expr] [TO expr] [STEP expr] [INTERPOLATE [(expr_list)]]
[LIMIT [offset_value, ]n BY columns]
[LIMIT [n, ]m] [WITH TIES]
[SETTINGS ...]
[UNION ALL ...]
[INTO OUTFILE filename [COMPRESSION type [LEVEL level]] ]
[FORMAT format]
```

Все секции являются необязательными, за исключением списка выражений сразу после `SELECT`, о котором более подробно будет рассказано [ниже](#select-clause).

Особенности каждой необязательной секции рассматриваются в отдельных разделах, которые перечислены в том же порядке, в каком они выполняются:

-   [Секция WITH](with.md)
-   [Секция SELECT](#select-clause)
-   [Секция DISTINCT](distinct.md)
-   [Секция FROM](from.md)
-   [Секция SAMPLE](sample.md)
-   [Секция JOIN](join.md)
-   [Секция PREWHERE](prewhere.md)
-   [Секция WHERE](where.md)
-   [Секция GROUP BY](/sql-reference/statements/select/group-by)
-   [Секция LIMIT BY](limit-by.md)
-   [Секция HAVING](having.md)
-   [Секция LIMIT](limit.md)
-   [Секция OFFSET](offset.md)
-   [Секция UNION ALL](union.md)
-   [Секция INTERSECT](intersect.md)
-   [Секция EXCEPT](except.md)
-   [Секция INTO OUTFILE](into-outfile.md)
-   [Секция FORMAT](format.md)

## Секция SELECT {#select-clause}

[Выражения](../../syntax.md#syntax-expressions) указанные в секции `SELECT` анализируются после завершения всех вычислений из секций, описанных выше. Вернее, анализируются выражения, стоящие над агрегатными функциями, если есть агрегатные функции.
Сами агрегатные функции и то, что под ними, вычисляются при агрегации (`GROUP BY`). Эти выражения работают так, как будто применяются к отдельным строкам результата.

Если в результат необходимо включить все столбцы, используйте символ звёздочка (`*`). Например, `SELECT * FROM ...`.

Чтобы включить в результат несколько столбцов, выбрав их имена с помощью регулярных выражений [re2](https://en.wikipedia.org/wiki/RE2_(software)), используйте выражение `COLUMNS`.

``` sql
COLUMNS('regexp')
```

Например, рассмотрим таблицу:

``` sql
CREATE TABLE default.col_names (aa Int8, ab Int8, bc Int8) ENGINE = TinyLog
```

Следующий запрос выбирает данные из всех столбцов, содержащих в имени символ `a`.

``` sql
SELECT COLUMNS('a') FROM col_names
```

``` text
┌─aa─┬─ab─┐
│  1 │  1 │
└────┴────┘
```

Выбранные стоблцы возвращаются не в алфавитном порядке.

В запросе можно использовать несколько выражений `COLUMNS`, а также вызывать над ними функции.

Например:

``` sql
SELECT COLUMNS('a'), COLUMNS('c'), toTypeName(COLUMNS('c')) FROM col_names
```

``` text
┌─aa─┬─ab─┬─bc─┬─toTypeName(bc)─┐
│  1 │  1 │  1 │ Int8           │
└────┴────┴────┴────────────────┘
```

Каждый столбец, возвращённый выражением `COLUMNS`, передаётся в функцию отдельным аргументом. Также можно передавать и другие аргументы, если функция их поддерживает. Аккуратно используйте функции. Если функция не поддерживает переданное количество аргументов, то ClickHouse генерирует исключение.

Например:

``` sql
SELECT COLUMNS('a') + COLUMNS('c') FROM col_names
```

``` text
Received exception from server (version 19.14.1):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: Number of arguments for function plus doesn't match: passed 3, should be 2.
```

В этом примере, `COLUMNS('a')` возвращает два столбца: `aa` и `ab`. `COLUMNS('c')` возвращает столбец `bc`. Оператор `+` не работает с тремя аргументами, поэтому ClickHouse генерирует исключение с соответствущим сообщением.

Столбцы, которые возвращаются выражением `COLUMNS` могут быть разных типов. Если `COLUMNS` не возвращает ни одного столбца и это единственное выражение в запросе `SELECT`, то ClickHouse генерирует исключение.

### Звёздочка {#asterisk}

В любом месте запроса, вместо выражения, может стоять звёздочка. При анализе запроса звёздочка раскрывается в список всех столбцов таблицы (за исключением `MATERIALIZED` и `ALIAS` столбцов). Есть лишь немного случаев, когда оправдано использовать звёздочку:

-   при создании дампа таблицы;
-   для таблиц, содержащих всего несколько столбцов - например, системных таблиц;
-   для получения информации о том, какие столбцы есть в таблице; в этом случае, укажите `LIMIT 1`. Но лучше используйте запрос `DESC TABLE`;
-   при наличии сильной фильтрации по небольшому количеству столбцов с помощью `PREWHERE`;
-   в подзапросах (так как из подзапросов выкидываются столбцы, не нужные для внешнего запроса).

В других случаях использование звёздочки является издевательством над системой, так как вместо преимуществ столбцовой СУБД вы получаете недостатки. То есть использовать звёздочку не рекомендуется.

### Экстремальные значения {#extreme-values}

Вы можете получить в дополнение к результату также минимальные и максимальные значения по столбцам результата. Для этого выставите настройку **extremes** в 1. Минимумы и максимумы считаются для числовых типов, дат, дат-с-временем. Для остальных столбцов будут выведены значения по умолчанию.

Вычисляются дополнительные две строчки - минимумы и максимумы, соответственно. Эти две дополнительные строки выводятся в [форматах](../../../interfaces/formats.md) `JSON*`, `TabSeparated*`, и `Pretty*` отдельно от остальных строчек. В остальных форматах они не выводится.

Во форматах `JSON*`, экстремальные значения выводятся отдельным полем ‘extremes’. В форматах `TabSeparated*`, строка выводится после основного результата и после ‘totals’ если есть. Перед ней (после остальных данных) вставляется пустая строка. В форматах `Pretty*`, строка выводится отдельной таблицей после основного результата и после `totals` если есть.

Экстремальные значения вычисляются для строк перед `LIMIT`, но после `LIMIT BY`. Однако при использовании `LIMIT offset, size`, строки перед `offset` включаются в `extremes`. В потоковых запросах, в результате может учитываться также небольшое количество строчек, прошедших `LIMIT`.

### Замечания {#notes}

Вы можете использовать синонимы (алиасы `AS`) в любом месте запроса.

В секциях `GROUP BY`, `ORDER BY` и `LIMIT BY` можно использовать не названия столбцов, а номера. Для этого нужно включить настройку [enable_positional_arguments](/operations/settings/settings#enable_positional_arguments). Тогда, например, в запросе с `ORDER BY 1,2` будет выполнена сортировка сначала по первому, а затем по второму столбцу.


## Детали реализации {#implementation-details}

Если в запросе отсутствуют секции `DISTINCT`, `GROUP BY`, `ORDER BY`, подзапросы в `IN` и `JOIN`, то запрос будет обработан полностью потоково, с использованием O(1) количества оперативки.
Иначе запрос может съесть много оперативки, если не указаны подходящие ограничения:

-   `max_memory_usage`
-   `max_rows_to_group_by`
-   `max_rows_to_sort`
-   `max_rows_in_distinct`
-   `max_bytes_in_distinct`
-   `max_rows_in_set`
-   `max_bytes_in_set`
-   `max_rows_in_join`
-   `max_bytes_in_join`
-   `max_bytes_before_external_sort`
-   `max_bytes_before_external_group_by`

Подробнее смотрите в разделе «Настройки». Присутствует возможность использовать внешнюю сортировку (с сохранением временных данных на диск) и внешнюю агрегацию.

## Модификаторы запроса SELECT {#select-modifiers}

Вы можете использовать следующие модификаторы в запросах `SELECT`.

### APPLY {#apply-modifier}

Вызывает указанную функцию для каждой строки, возвращаемой внешним табличным выражением запроса.

**Синтаксис:**

``` sql
SELECT <expr> APPLY( <func> ) FROM [db.]table_name
```

**Пример:**

``` sql
CREATE TABLE columns_transformers (i Int64, j Int16, k Int64) ENGINE = MergeTree ORDER by (i);
INSERT INTO columns_transformers VALUES (100, 10, 324), (120, 8, 23);
SELECT * APPLY(sum) FROM columns_transformers;
```

```
┌─sum(i)─┬─sum(j)─┬─sum(k)─┐
│    220 │     18 │    347 │
└────────┴────────┴────────┘
```

### EXCEPT {#except-modifier}

Исключает из результата запроса один или несколько столбцов.

**Синтаксис:**

``` sql
SELECT <expr> EXCEPT ( col_name1 [, col_name2, col_name3, ...] ) FROM [db.]table_name
```

**Пример:**

``` sql
SELECT * EXCEPT (i) from columns_transformers;
```

```
┌──j─┬───k─┐
│ 10 │ 324 │
│  8 │  23 │
└────┴─────┘
```

### REPLACE {#replace-modifier}

Определяет одно или несколько [выражений алиасов](/sql-reference/syntax#expression-aliases). Каждый алиас должен соответствовать имени столбца из запроса `SELECT *`. В списке столбцов результата запроса имя столбца, соответствующее алиасу, заменяется выражением в модификаторе `REPLACE`.

Этот модификатор не изменяет имена или порядок столбцов. Однако он может изменить значение и тип значения.

**Синтаксис:**

``` sql
SELECT <expr> REPLACE( <expr> AS col_name) from [db.]table_name
```

**Пример:**

``` sql
SELECT * REPLACE(i + 1 AS i) from columns_transformers;
```

```
┌───i─┬──j─┬───k─┐
│ 101 │ 10 │ 324 │
│ 121 │  8 │  23 │
└─────┴────┴─────┘
```

### Комбинации модификаторов {#modifier-combinations}

Вы можете использовать каждый модификатор отдельно или комбинировать их.

**Примеры:**

Использование одного и того же модификатора несколько раз.

``` sql
SELECT COLUMNS('[jk]') APPLY(toString) APPLY(length) APPLY(max) from columns_transformers;
```

```
┌─max(length(toString(j)))─┬─max(length(toString(k)))─┐
│                        2 │                        3 │
└──────────────────────────┴──────────────────────────┘
```

Использование нескольких модификаторов в одном запросе.

``` sql
SELECT * REPLACE(i + 1 AS i) EXCEPT (j) APPLY(sum) from columns_transformers;
```

```
┌─sum(plus(i, 1))─┬─sum(k)─┐
│             222 │    347 │
└─────────────────┴────────┘
```

## SETTINGS в запросе SELECT {#settings-in-select-query}

Вы можете задать значения необходимых настроек непосредственно в запросе `SELECT` в секции `SETTINGS`. Эти настройки действуют только в рамках данного запроса, а после его выполнения сбрасываются до предыдущего значения или значения по умолчанию.

Другие способы задания настроек описаны [здесь](../../../operations/settings/index.md).

**Пример**

``` sql
SELECT * FROM some_table SETTINGS optimize_read_in_order=1, cast_keep_nullable=1;
```
