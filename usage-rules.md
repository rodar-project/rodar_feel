# Rules for working with RodarFeel

## Understanding RodarFeel

RodarFeel is a standalone FEEL (Friendly Enough Expression Language) evaluator for Elixir. FEEL is the standard expression language for BPMN 2.0 and DMN. It parses expression strings into an AST and evaluates them against a bindings map. All results are returned as `{:ok, value}` or `{:error, reason}` tuples.

## API Overview

RodarFeel exposes two public functions:

- `RodarFeel.eval/2` — evaluate a FEEL expression against bindings
- `RodarFeel.eval_unary/3` — evaluate a DMN unary test against an input value

Always use these entry points. Do not call `RodarFeel.Parser` or `RodarFeel.Evaluator` directly unless you have a specific reason to separate parsing from evaluation (e.g., caching parsed ASTs).

## Bindings

Bindings are plain Elixir maps. Both **string keys** and **atom keys** are accepted — string keys are canonical and take precedence when both exist for the same name.

```elixir
# GOOD — string keys (canonical)
RodarFeel.eval("amount > 1000", %{"amount" => 1500})

# GOOD — atom keys also work
RodarFeel.eval("amount > 1000", %{amount: 1500})

# String key wins when both exist
RodarFeel.eval("x", %{x: 1, "x" => 2})  # => {:ok, 2}
```

Nested maps work with dot-path access:

```elixir
RodarFeel.eval("order.total", %{"order" => %{"total" => 42}})
# => {:ok, 42}
```

## Result Handling

All evaluations return `{:ok, value}` or `{:error, reason}`. Use pattern matching:

```elixir
# GOOD — pattern match on the result
case RodarFeel.eval(expr, bindings) do
  {:ok, result} -> handle_result(result)
  {:error, reason} -> handle_error(reason)
end

# BAD — assuming success
{:ok, result} = RodarFeel.eval(untrusted_expr, bindings)
```

There is no bang (`!`) variant. The library never raises on evaluation — errors are always returned as tuples.

## Null Propagation

FEEL uses three-valued logic. Missing bindings resolve to `nil`, and `nil` propagates through arithmetic:

```elixir
RodarFeel.eval("missing + 5", %{})
# => {:ok, nil}  — not an error

RodarFeel.eval("nil > 5", %{})
# => {:ok, false}  — comparison with nil returns false

RodarFeel.eval("true and nil", %{})
# => {:ok, nil}  — three-valued boolean logic
```

Do not wrap FEEL calls in `try/rescue` for nil handling — null propagation is by design.

## String Expressions

FEEL strings use double quotes. When embedding in Elixir strings, use sigils to avoid escaping:

```elixir
# GOOD — sigil avoids escaping
RodarFeel.eval(~S(if status = "active" then "yes" else "no"), bindings)

# OK but verbose — escaped quotes
RodarFeel.eval("if status = \"active\" then \"yes\" else \"no\"", bindings)

# GOOD — ~s with | delimiters
RodarFeel.eval(~s|name = "Alice"|, bindings)
```

## Temporal Types

### Literals

Use the `@"..."` syntax for temporal literals in FEEL expressions:

```elixir
RodarFeel.eval(~s|@"2024-03-20"|, %{})             # => {:ok, ~D[2024-03-20]}
RodarFeel.eval(~s|@"10:30:00"|, %{})                # => {:ok, ~T[10:30:00]}
RodarFeel.eval(~s|@"2024-03-20T10:30:00"|, %{})     # => {:ok, ~N[2024-03-20 10:30:00]}
RodarFeel.eval(~s|@"2024-03-20T10:30:00Z"|, %{})    # => {:ok, ~U[2024-03-20 10:30:00Z]}
RodarFeel.eval(~s|@"P1Y2M"|, %{})                   # => {:ok, %RodarFeel.Duration{years: 1, months: 2}}
```

### Passing Temporal Values via Bindings

You can pass Elixir `Date`, `Time`, `NaiveDateTime`, `DateTime`, and `RodarFeel.Duration` structs directly in bindings:

```elixir
RodarFeel.eval("d.year", %{"d" => ~D[2024-03-20]})
# => {:ok, 2024}

RodarFeel.eval("dt.timezone", %{"dt" => DateTime.utc_now()})
# => {:ok, "Etc/UTC"}
```

### Timezone Support

Timezone-aware datetimes are supported via the `tz` library:

```elixir
# UTC via literal
RodarFeel.eval(~s|@"2024-03-20T10:30:00Z"|, %{})

# Offset via literal (normalized to UTC)
RodarFeel.eval(~s|@"2024-03-20T10:30:00+05:00"|, %{})

# Named timezone via construction function
RodarFeel.eval(~s|date and time(@"2024-03-20T10:30:00", "America/New_York")|, %{})
```

Without a timezone suffix (Z or ±HH:MM), datetimes parse as `NaiveDateTime`.

### Temporal Arithmetic

Temporal values support `+` and `-` with durations, and subtraction between same-type values:

```elixir
RodarFeel.eval(~s|@"2024-03-20" + @"P10D"|, %{})          # date + duration => date
RodarFeel.eval(~s|@"2024-03-20" - @"2024-03-10"|, %{})     # date - date => duration
RodarFeel.eval(~s|@"10:30:00" + @"PT2H"|, %{})             # time + duration => time
```

### Property Access

Access components via dot notation: `.year`, `.month`, `.day`, `.hour`, `.minute`, `.second`, `.timezone`, `.offset`.

```elixir
RodarFeel.eval(~s|@"2024-03-20".year|, %{})       # => {:ok, 2024}
RodarFeel.eval(~s|@"10:30:00".minute|, %{})        # => {:ok, 30}
```

Note: property access on function call results (e.g., `now().year`) is not supported. Assign to a variable first:

```elixir
# This won't work: now().year
# Instead, use a binding or context:
RodarFeel.eval("{n: now(), year: n.year}", %{})
```

## DMN Unary Tests

Use `eval_unary/3` for DMN decision table cell evaluation. The input value is the first argument — it is implicit in the test expression:

```elixir
RodarFeel.eval_unary("< 100", 50)                    # => {:ok, true}
RodarFeel.eval_unary("[1..5]", 3)                     # => {:ok, true}
RodarFeel.eval_unary("(1..5)", 1)                     # => {:ok, false} — exclusive
RodarFeel.eval_unary("not(< 100)", 200)               # => {:ok, true}
RodarFeel.eval_unary("1, 2, 3", 2)                    # => {:ok, true}
RodarFeel.eval_unary("-", :anything)                   # => {:ok, true} — wildcard
RodarFeel.eval_unary(~s|"high", "low"|, "high")       # => {:ok, true}
```

Unary tests support bindings as the third argument:

```elixir
RodarFeel.eval_unary("> threshold", 150, %{"threshold" => 100})
# => {:ok, true}
```

## User-Defined Functions (Lambdas)

FEEL supports lambdas with the `function(params) body` syntax:

```elixir
# Define and invoke via context
RodarFeel.eval("{sq: function(x) x * x, result: sq(5)}", %{})
# => {:ok, %{"sq" => {:feel_function, ...}, "result" => 25}}

# Pass lambdas via bindings
{:ok, double} = RodarFeel.eval("function(x) x * 2", %{})
RodarFeel.eval("for x in items return f(x)", %{"items" => [1, 2, 3], "f" => double})
# => {:ok, [2, 4, 6]}
```

Lambdas capture their closure at definition time. The internal representation is `{:feel_function, params, body_ast, closure_bindings}`.

## Instance Of

Type checking uses the `instance of` operator with FEEL type names:

```elixir
RodarFeel.eval("x instance of number", %{"x" => 42})       # => {:ok, true}
RodarFeel.eval("x instance of string", %{"x" => 42})       # => {:ok, false}
```

Supported type names: `number`, `string`, `boolean`, `date`, `time`, `date and time`, `duration`, `years and months duration`, `days and time duration`, `list`, `context`, `function`, `null`, `any`.

## Built-in Functions (48)

### Naming Convention

Multi-word function names use spaces, matching the FEEL spec:

```elixir
RodarFeel.eval(~s|string length("hello")|, %{})      # => {:ok, 5}
RodarFeel.eval(~s|string join(["a", "b"], "-")|, %{}) # => {:ok, "a-b"}
RodarFeel.eval(~s|date and time("2024-03-20T10:30:00", "UTC")|, %{})
```

### Null Propagation in Functions

Most functions propagate null — if any argument is `nil`, the result is `nil`. Exceptions:

- `is null(v)` — returns `true` for nil
- `not(v)` — returns `nil` for nil input
- `all(list)` / `any(list)` — three-valued logic (`false and nil` → `false`)
- `string(v)` — returns `nil` only for nil input, converts all other types

### Function Reference

| Category    | Functions |
|-------------|-----------|
| Numeric     | `abs`, `floor`, `ceiling`, `round(n)`, `round(n, scale)`, `min`, `max`, `sum`, `count`, `product`, `mean` |
| String      | `string length`, `contains`, `starts with`, `ends with`, `upper case`, `lower case`, `substring`, `split`, `substring before`, `substring after`, `replace`, `trim`, `string join`, `matches` |
| List        | `append`, `concatenate`, `reverse`, `flatten`, `distinct values`, `sort`, `index of`, `list contains` |
| Boolean     | `not`, `is null`, `all`, `any` |
| Conversion  | `string`, `number(s)`, `number(s, grouping, decimal)` |
| Temporal    | `date(s)`, `date(y,m,d)`, `time(s)`, `time(h,m,s)`, `date and time(s)`, `date and time(d,t)`, `date and time(ndt,tz)`, `date and time(d,t,tz)`, `duration(s)`, `now()`, `today()` |
| Statistical | `median`, `stddev`, `mode` |
| Misc        | `random()` |

### Locale-Aware Number Parsing

```elixir
RodarFeel.eval(~s|number("1,000.50", ",", ".")|, %{})   # US format => {:ok, 1000.5}
RodarFeel.eval(~s|number("1.000,50", ".", ",")|, %{})    # EU format => {:ok, 1000.5}
```

### Regex Matching

The `matches` function uses Elixir/PCRE regex syntax:

```elixir
RodarFeel.eval(~s|matches("hello", "^h.*o$")|, %{})  # => {:ok, true}
```

## Common Patterns

### Decision Table Evaluation

```elixir
# Define rules as {test, output} pairs
rules = [
  {"< 18", "minor"},
  {"[18..65]", "adult"},
  {"> 65", "senior"}
]

age = 30
{_test, label} = Enum.find(rules, fn {test, _} ->
  {:ok, true} == RodarFeel.eval_unary(test, age)
end)
# label => "adult"
```

### Dynamic Expression Evaluation in BPMN

```elixir
# Process variables as bindings
bindings = %{
  "amount" => order.total,
  "customer_type" => customer.type,
  "items" => order.items
}

# Evaluate a gateway condition
{:ok, should_route} = RodarFeel.eval(gateway.condition_expression, bindings)
```

### Caching Parsed ASTs

If evaluating the same expression repeatedly with different bindings, parse once and evaluate many:

```elixir
{:ok, ast} = RodarFeel.Parser.parse("amount > threshold")

Enum.map(data_rows, fn row ->
  {:ok, result} = RodarFeel.Evaluator.evaluate(ast, row)
  result
end)
```

## Architecture

- **`RodarFeel`** — public API, the only module you should call in application code
- **`RodarFeel.Parser`** — NimbleParsec-based parser, produces AST tuples. Use directly only for AST caching.
- **`RodarFeel.Evaluator`** — tree-walking evaluator. Use directly only with pre-parsed ASTs.
- **`RodarFeel.Functions`** — function dispatch. Not intended for direct use.
- **`RodarFeel.Duration`** — ISO 8601 duration struct. You may construct these directly for bindings.

## Dependencies

- `nimble_parsec` — parser combinators (compile-time only, zero runtime overhead)
- `tz` — IANA timezone database (lightweight, uses Mint not Hackney)

## Common Mistakes

### Atom keys in bindings

Atom keys now work transparently, but string keys are still canonical and recommended for clarity. When both an atom and string key exist for the same name, the string key takes precedence.

```elixir
# Both work
RodarFeel.eval("name", %{name: "Alice"})        # => {:ok, "Alice"}
RodarFeel.eval("name", %{"name" => "Alice"})     # => {:ok, "Alice"}

# String key wins when both exist
RodarFeel.eval("x", %{x: 1, "x" => 2})          # => {:ok, 2}
```

### Expecting exceptions on invalid input

```elixir
# RodarFeel never raises on evaluation errors
# BAD
try do
  RodarFeel.eval(bad_expr, %{})
rescue
  _ -> handle_error()
end

# GOOD
case RodarFeel.eval(bad_expr, %{}) do
  {:ok, result} -> result
  {:error, reason} -> handle_error(reason)
end
```

### Confusing FEEL equality with Elixir

FEEL uses `=` for equality (not `==`). FEEL `!=` works as expected.

```elixir
# In FEEL expressions
RodarFeel.eval(~s|status = "active"|, %{"status" => "active"})   # => {:ok, true}
RodarFeel.eval(~s|status != "active"|, %{"status" => "pending"}) # => {:ok, true}
```

### FEEL lists are 1-indexed

FEEL uses 1-based indexing, but bracket access on lists in the evaluator uses Elixir's 0-based `Enum.at/2`:

```elixir
# FEEL substring is 1-based
RodarFeel.eval(~s|substring("hello", 1, 3)|, %{})  # => {:ok, "hel"}

# Bracket list access is 0-based (Elixir convention)
RodarFeel.eval("items[0]", %{"items" => ["a", "b", "c"]})  # => {:ok, "a"}
```

### Duration subtype comparison

Only durations of the same subtype (year-month or day-time) can be compared:

```elixir
# GOOD — same subtype
RodarFeel.eval(~s|@"P2Y" > @"P1Y"|, %{})     # => {:ok, true}
RodarFeel.eval(~s|@"PT2H" > @"PT1H"|, %{})    # => {:ok, true}

# ERROR — mixed subtypes
RodarFeel.eval(~s|@"P1Y" > @"PT1H"|, %{})     # => {:error, "cannot compare mixed duration types"}
```
