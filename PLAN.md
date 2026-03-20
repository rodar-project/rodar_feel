# RodarFeel — Enhancement Roadmap

## Context

We extracted FEEL into the standalone `rodar_feel` package. This plan tracks enhancements compared against [`feel_ex`](https://github.com/andimon/feel_ex) (v0.2.0, Dec 2024) and the DMN FEEL spec.

**Our advantages**: Lighter weight, correct null/three-valued semantics, cleaner `{:ok, value}` API, minimal deps (only `nimble_parsec`).

---

## Phase 1: Quick Wins — DONE

### New functions (18 total)

- [x] **String**: `split/2`, `substring before/2`, `substring after/2`, `replace/3`, `trim/1`
- [x] **List**: `append/2`, `concatenate/2+` (variadic), `reverse/1`, `flatten/1`, `distinct values/1`, `sort/1`, `index of/2`, `list contains/2`
- [x] **Conversion**: `string/1`
- [x] **Boolean**: `all/1`, `any/1` (three-valued)
- [x] **Numeric**: `product/1`, `mean/1`

### New operators/syntax

- [x] `between X and Y` — desugars to range check, AST node `{:between, expr, low, high}`
- [x] Comments — `//` single-line, `/* */` multi-line (ignored in lexer)

### Files modified

- `lib/rodar_feel/parser.ex` — multi-word function names, `between`, comments in `ws`
- `lib/rodar_feel/functions.ex` — 18 new function dispatches
- `lib/rodar_feel/evaluator.ex` — `{:between, ...}` handler

---

## Phase 2: Expression Features — DONE

### Context literals

- [x] `{a: 1, b: a + 1}` — sequential evaluation, earlier entries visible to later ones
- [x] Keys: unquoted identifiers or quoted strings
- [x] AST: `{:context, [{key_string, expr}, ...]}`
- [x] Evaluates to Elixir map with string keys

### For-in-return

- [x] `for x in [1,2,3] return x * 2` → `[2, 4, 6]`
- [x] Multiple iteration variables (cartesian product): `for x in xs, y in ys return x + y`
- [x] AST: `{:for, [{var_string, collection_expr}], body_expr}`

### Quantified expressions

- [x] `some x in list satisfies x > 2` — existential, short-circuits on `true`
- [x] `every x in list satisfies x > 0` — universal, short-circuits on `false`
- [x] Three-valued boolean logic (nil propagation)
- [x] AST: `{:some, ...}` / `{:every, ...}`

### Files modified

- `lib/rodar_feel/parser.ex` — context, for, some/every combinators with keyword reservation
- `lib/rodar_feel/evaluator.ex` — scoped variable binding, iteration, three-valued quantifiers

---

## Phase 3: Temporal Types — DONE

The biggest remaining gap. Options ranked by effort:

### Option A: Minimal (no timezone dep) — RECOMMENDED FIRST

Use Elixir's built-in `Date`, `Time`, `DateTime`, `NaiveDateTime` — no `tzdata` dependency.

#### 3A.1 Temporal literal parsing

- [x] `@"2024-03-20"` → `~D[2024-03-20]` (date)
- [x] `@"10:30:00"` → `~T[10:30:00]` (time)
- [x] `@"2024-03-20T10:30:00"` → `~N[2024-03-20 10:30:00]` (datetime, naive)
- [x] `@"P1Y2M3D"` / `@"PT1H30M"` → duration struct (ISO 8601)
- [x] AST: `{:literal, %Date{}}`, `{:literal, %Time{}}`, etc.

#### 3A.2 Temporal construction functions

- [x] `date(year, month, day)` → `Date`
- [x] `date(string)` → parse ISO date string
- [x] `time(hour, minute, second)` → `Time`
- [x] `time(string)` → parse ISO time string
- [x] `date and time(string)` → parse ISO datetime (multi-word function)
- [x] `date and time(date, time)` → combine date + time
- [x] `duration(string)` → parse ISO 8601 duration
- [x] `now()` → current datetime (UTC)
- [x] `today()` → current date (UTC)

#### 3A.3 Temporal property access

- [x] `.year`, `.month`, `.day` on dates/datetimes
- [x] `.hour`, `.minute`, `.second` on times/datetimes
- [x] Path resolution must handle property access on temporal values

#### 3A.4 Temporal arithmetic

- [x] `date + duration` → new date
- [x] `date - date` → duration
- [x] `date - duration` → new date
- [x] `time + duration` → new time
- [x] `datetime + duration` → new datetime
- [x] Comparison operators on temporal types (already work via Elixir's `<`/`>` for Date/Time)

#### 3A.5 Duration handling

- [x] Define `RodarFeel.Duration` struct for year-month and day-time durations
- [x] FEEL distinguishes `years and months duration` from `days and time duration`
- [x] Duration comparison and arithmetic

#### Files to modify

- `lib/rodar_feel/parser.ex` — `@"..."` temporal literal syntax
- `lib/rodar_feel/evaluator.ex` — temporal arithmetic in `eval_binop`, property access
- `lib/rodar_feel/functions.ex` — `date()`, `time()`, `now()`, `today()`, `duration()`, `date and time()`
- `lib/rodar_feel/duration.ex` — NEW: duration struct and operations

### Option B: Full (with timezone support) — DONE

Extends Option A with timezone-aware datetime using the `tz` library.

- [x] `@"2024-03-20T10:30:00Z"` → `DateTime` (UTC)
- [x] `@"2024-03-20T10:30:00+05:00"` → `DateTime` (offset, normalized to UTC)
- [x] `date and time(naive_dt, "America/New_York")` → `DateTime` with named timezone
- [x] `date and time(date, time, "Europe/London")` → 3-arg form with timezone
- [x] `.timezone` and `.offset` property access on `DateTime`
- [x] `DateTime ± Duration`, `DateTime - DateTime` arithmetic (preserves timezone)
- [x] `DateTime` comparison (cross-offset via UTC normalization)
- [x] `now()` returns UTC `DateTime` instead of `NaiveDateTime`
- [x] DST ambiguity and gap handling

---

## Phase 4: Unary Tests — DONE

Separate parser entry point for DMN unary test syntax.

- [x] `< 100` — comparison test
- [x] `[1..5]` — range test (inclusive)
- [x] `(1..5)` — range test (exclusive)
- [x] `[1..5)` / `(1..5]` — half-open ranges
- [x] `not(< 100)` — negated test
- [x] `1, 2, 3` — disjunction (match any)
- [x] `-` — wildcard (match anything)

#### API

- [x] `RodarFeel.eval_unary(test_string, input_value, bindings)` — new entry point
- [x] AST: `{:unary_wildcard}`, `{:unary_cmp, ...}`, `{:unary_range, ...}`, `{:unary_not, ...}`, `{:unary_disjunction, ...}`, `{:unary_value, ...}`

#### Files modified

- `lib/rodar_feel/parser.ex` — new `defparsec(:parse_unary_test, ...)` entry point, `parse_unary/1` public API
- `lib/rodar_feel/evaluator.ex` — `evaluate_unary/3` with temporal comparison support in ranges
- `lib/rodar_feel.ex` — new `eval_unary/3` public function

---

## Phase 5: Nice to Have — DONE

- [x] `instance of` type checking — all FEEL types including `date and time`, `years and months duration`, `days and time duration`, `any`
- [x] `number(string)` — parse string to number
- [x] `number(from, grouping, decimal)` — locale-aware number parsing
- [x] Statistical functions: `median/1`, `stddev/1`, `mode/1`
- [x] `random()` — random number generation
- [x] User-defined functions / lambdas — `function(x, y) x + y` with closures, context scoping, higher-order usage
- [x] `matches(string, pattern)` — regex matching
- [x] `string join(list, delimiter)` — join list into string with null filtering

---

## Bugs / Issues in feel_ex (things we avoid)

For reference — pitfalls we've deliberately avoided:

- No null propagation crashes — our `nil + 1` returns `nil`, not an exception
- No three-valued logic gaps — `true and nil` → `nil`, `false and nil` → `false`
- No atom exhaustion risk — we use string keys throughout
- No heavy deps — no `tzdata`/`hackney` transitive chain
- No wrapped value types — plain Elixir values, clean `{:ok, value}` API
- No compile-time Logger.info calls in parser

---

## Current Coverage Summary

| Category    | Functions                                                                                                                                                           | Count  |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Numeric     | `abs`, `floor`, `ceiling`, `round`, `min`, `max`, `sum`, `count`, `product`, `mean`                                                                                 | 10     |
| String      | `string length`, `contains`, `starts with`, `ends with`, `upper case`, `lower case`, `substring`, `split`, `substring before`, `substring after`, `replace`, `trim`, `string join`, `matches` | 14     |
| List        | `append`, `concatenate`, `reverse`, `flatten`, `distinct values`, `sort`, `index of`, `list contains`                                                               | 8      |
| Boolean     | `not`, `is null`, `all`, `any`                                                                                                                                      | 4      |
| Conversion  | `string`, `number`                                                                                                                                                  | 2      |
| Temporal    | `date`, `time`, `date and time`, `duration`, `now`, `today`                                                                                                         | 6      |
| Statistical | `median`, `stddev`, `mode`                                                                                                                                          | 3      |
| Misc        | `random`                                                                                                                                                            | 1      |
| **Total**   |                                                                                                                                                                     | **48** |

| Feature                                      | Status |
| -------------------------------------------- | ------ |
| Arithmetic (`+`, `-`, `*`, `/`, `%`, `**`)   | Done   |
| Comparison (`=`, `!=`, `<`, `>`, `<=`, `>=`) | Done   |
| Boolean (`and`, `or`, `not`)                 | Done   |
| `in` operator (list + range)                 | Done   |
| `between X and Y`                            | Done   |
| `if-then-else`                               | Done   |
| Path access (`a.b.c`)                        | Done   |
| Bracket access (`a["key"]`, `a[0]`)          | Done   |
| List literals (`[1, 2, 3]`)                  | Done   |
| Context literals (`{a: 1, b: 2}`)            | Done   |
| For-in-return                                | Done   |
| Quantified (`some`/`every`)                  | Done   |
| Comments (`//`, `/* */`)                     | Done   |
| Null propagation                             | Done   |
| Three-valued boolean logic                   | Done   |
| Temporal types                               | Done   |
| Timezone-aware datetime                      | Done   |
| Unary tests (DMN)                            | Done   |
| `instance of`                                | Done   |
| User-defined functions / lambdas             | Done   |
