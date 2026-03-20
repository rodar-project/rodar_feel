# RodarFeel

[![Hex.pm](https://img.shields.io/hexpm/v/rodar_feel.svg)](https://hex.pm/packages/rodar_feel)

A standalone FEEL (Friendly Enough Expression Language) evaluator for Elixir. FEEL is the standard expression language for BPMN 2.0 and DMN.

Extracted from the [Rodar](https://github.com/rodar-project/rodar) BPMN engine for independent use.

## Installation

Add `rodar_feel` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:rodar_feel, "~> 0.1.0"}]
end
```

## Usage

```elixir
# Simple arithmetic
RodarFeel.eval("1 + 2", %{})
# => {:ok, 3}

# Variable bindings
RodarFeel.eval("amount > 1000", %{"amount" => 1500})
# => {:ok, true}

# If-then-else
RodarFeel.eval(~S(if x > 10 then "high" else "low"), %{"x" => 15})
# => {:ok, "high"}

# Built-in functions
RodarFeel.eval("string length(name)", %{"name" => "Alice"})
# => {:ok, 5}

# List and range membership
RodarFeel.eval(~S(status in ["active", "pending"]), %{"status" => "active"})
# => {:ok, true}

RodarFeel.eval("age in 18..65", %{"age" => 30})
# => {:ok, true}

# Null handling
RodarFeel.eval("missing + 5", %{})
# => {:ok, nil}

# Temporal types
RodarFeel.eval(~S(@"2024-03-20" + @"P10D"), %{})
# => {:ok, ~D[2024-03-30]}

RodarFeel.eval(~S(@"2024-03-20".year), %{})
# => {:ok, 2024}

# Timezone-aware datetime
RodarFeel.eval(~S(date and time(@"2024-03-20T10:30:00", "America/New_York")), %{})
# => {:ok, #DateTime<2024-03-20 10:30:00-04:00 EDT America/New_York>}

# Context literals
RodarFeel.eval("{a: 1, b: a + 1}", %{})
# => {:ok, %{"a" => 1, "b" => 2}}

# For-in-return
RodarFeel.eval("for x in [1, 2, 3] return x * 2", %{})
# => {:ok, [2, 4, 6]}

# Quantified expressions
RodarFeel.eval("some x in [1, 2, 3] satisfies x > 2", %{})
# => {:ok, true}

# User-defined functions (lambdas)
RodarFeel.eval("{sq: function(x) x * x, result: sq(5)}", %{})
# => {:ok, %{"sq" => {:feel_function, ...}, "result" => 25}}

# DMN unary tests
RodarFeel.eval_unary("< 100", 50)
# => {:ok, true}

RodarFeel.eval_unary("[1..5]", 3)
# => {:ok, true}

RodarFeel.eval_unary("1, 2, 3", 2)
# => {:ok, true}
```

## Features

### Expression Language

- **Arithmetic** — `+`, `-`, `*`, `/`, `%`, `**`
- **Comparison** — `=`, `!=`, `<`, `>`, `<=`, `>=`
- **Boolean logic** — `and`, `or`, `not` (three-valued)
- **Null propagation** — `nil + 1` evaluates to `nil`
- **String concatenation** — `"hello" + " world"` via `+`
- **Path access** — `order.customer.name` resolves nested maps
- **Bracket access** — `data["key"]` and `items[0]`
- **If-then-else** — `if condition then a else b`
- **In operator** — list membership and range checks
- **Between** — `x between 1 and 10`
- **List literals** — `[1, 2, 3]`
- **Context literals** — `{a: 1, b: a + 1}` with sequential evaluation
- **For-in-return** — `for x in list return expr` with cartesian product support
- **Quantified** — `some`/`every x in list satisfies condition`
- **Instance of** — `x instance of number` (all FEEL types)
- **User-defined functions** — `function(x, y) x + y` with closures
- **Comments** — `//` single-line, `/* */` multi-line

### Temporal Types

- **Literals** — `@"2024-03-20"` (date), `@"10:30:00"` (time), `@"2024-03-20T10:30:00"` (datetime)
- **Timezone-aware** — `@"2024-03-20T10:30:00Z"`, `@"2024-03-20T10:30:00+05:00"`, named zones via `date and time(ndt, "America/New_York")`
- **Durations** — `@"P1Y2M"` (year-month), `@"PT1H30M"` (day-time)
- **Property access** — `.year`, `.month`, `.day`, `.hour`, `.minute`, `.second`, `.timezone`, `.offset`
- **Arithmetic** — `date + duration`, `date - date`, `datetime ± duration`, `time ± duration`
- **Comparison** — dates, times, datetimes, and durations are comparable

### DMN Unary Tests

Separate entry point for DMN decision table cells via `RodarFeel.eval_unary/3`:

- `-` — wildcard (match anything)
- `< 100`, `>= 5`, `= "foo"` — comparison tests
- `[1..5]`, `(1..5)`, `[1..5)`, `(1..5]` — range tests (inclusive/exclusive/half-open)
- `not(< 100)` — negated test
- `1, 2, 3` — disjunction (match any)

### Built-in Functions (48)

| Category    | Functions |
|-------------|-----------|
| Numeric     | `abs`, `floor`, `ceiling`, `round`, `min`, `max`, `sum`, `count`, `product`, `mean` |
| String      | `string length`, `contains`, `starts with`, `ends with`, `upper case`, `lower case`, `substring`, `split`, `substring before`, `substring after`, `replace`, `trim`, `string join`, `matches` |
| List        | `append`, `concatenate`, `reverse`, `flatten`, `distinct values`, `sort`, `index of`, `list contains` |
| Boolean     | `not`, `is null`, `all`, `any` |
| Conversion  | `string`, `number` |
| Temporal    | `date`, `time`, `date and time`, `duration`, `now`, `today` |
| Statistical | `median`, `stddev`, `mode` |
| Misc        | `random` |

## Architecture

- `RodarFeel` — public API (`eval/2`, `eval_unary/3`)
- `RodarFeel.Parser` — NimbleParsec-based parser producing AST tuples
- `RodarFeel.Evaluator` — tree-walking evaluator with null propagation and three-valued logic
- `RodarFeel.Functions` — built-in function dispatch (48 functions)
- `RodarFeel.Duration` — ISO 8601 duration struct with arithmetic and comparison

## Dependencies

- [`nimble_parsec`](https://hex.pm/packages/nimble_parsec) — parser combinators
- [`tz`](https://hex.pm/packages/tz) — IANA timezone database (lightweight, no `hackney`)

## License

Apache-2.0. See [LICENSE.md](LICENSE.md).
