# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Phase 1 — Quick Wins**: 18 new built-in functions
  - String: `split`, `substring before`, `substring after`, `replace`, `trim`
  - List: `append`, `concatenate`, `reverse`, `flatten`, `distinct values`, `sort`, `index of`, `list contains`
  - Conversion: `string`
  - Boolean: `all`, `any` (three-valued)
  - Numeric: `product`, `mean`
  - `between X and Y` operator
  - Comments: `//` single-line, `/* */` multi-line

- **Phase 2 — Expression Features**:
  - Context literals: `{a: 1, b: a + 1}` with sequential evaluation
  - For-in-return: `for x in list return expr` with cartesian product
  - Quantified expressions: `some`/`every x in list satisfies condition` (three-valued)

- **Phase 3 — Temporal Types**:
  - `RodarFeel.Duration` struct for ISO 8601 durations
  - Temporal literal syntax: `@"2024-03-20"`, `@"10:30:00"`, `@"2024-03-20T10:30:00"`, `@"P1Y2M"`
  - Timezone-aware datetime: `@"2024-03-20T10:30:00Z"`, `@"2024-03-20T10:30:00+05:00"`
  - Named timezone support via `tz` library: `date and time(ndt, "America/New_York")`
  - Temporal construction functions: `date`, `time`, `date and time`, `duration`, `now`, `today`
  - Property access: `.year`, `.month`, `.day`, `.hour`, `.minute`, `.second`, `.timezone`, `.offset`
  - Temporal arithmetic: date ± duration, date - date, time ± duration, datetime ± duration
  - Temporal comparison using proper `Date.compare/2`, `Time.compare/2`, `DateTime.compare/2`
  - `now()` returns timezone-aware UTC `DateTime`

- **Phase 4 — Unary Tests**:
  - `RodarFeel.eval_unary/3` — new public API for DMN decision table cells
  - Wildcard (`-`), comparison tests (`< 100`), range tests (`[1..5]`, `(1..5)`, half-open)
  - Negated tests (`not(< 100)`), disjunctions (`1, 2, 3`)
  - Supports bindings and temporal values in all test types

- **Phase 5 — Nice to Have**:
  - `instance of` type checking for all FEEL types
  - `number(string)` and `number(string, grouping, decimal)` for locale-aware parsing
  - Statistical functions: `median`, `stddev`, `mode`
  - `random()` for random number generation
  - `matches(string, pattern)` for regex matching
  - `string join(list)` / `string join(list, delimiter)` with null filtering
  - User-defined functions / lambdas: `function(x, y) x + y` with closures and higher-order usage

### Changed

- `now()` returns a timezone-aware UTC `DateTime` instead of `NaiveDateTime`

### Dependencies

- Added `tz` ~> 0.28 for IANA timezone database support

## [0.1.0] - 2026-03-19

### Added

- Initial release extracted from [Rodar](https://github.com/rodar-project/rodar)
- `RodarFeel.eval/2` — parse and evaluate FEEL expressions
- `RodarFeel.Parser` — NimbleParsec-based FEEL parser producing AST
- `RodarFeel.Evaluator` — tree-walking evaluator with null propagation and three-valued boolean logic
- `RodarFeel.Functions` — built-in FEEL functions (numeric, string, boolean, null)
