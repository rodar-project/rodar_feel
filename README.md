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
```

## Features

- **Null propagation** — `nil + 1` evaluates to `nil`
- **Three-valued boolean logic** — `true and nil` evaluates to `nil`, `false and nil` evaluates to `false`
- **String concatenation** — `"hello" + " world"` via `+`
- **Path access** — `order.customer.name` resolves nested maps
- **Bracket access** — `data["key"]` and `items[0]`
- **If-then-else** — `if condition then a else b`
- **In operator** — list membership and range checks
- **Built-in functions** — numeric, string, boolean, and null functions

### Built-in Functions

| Category | Functions |
|----------|-----------|
| Numeric | `abs(n)`, `floor(n)`, `ceiling(n)`, `round(n)`, `round(n, scale)`, `min(list)`, `max(list)`, `sum(list)`, `count(list)` |
| String | `string length(s)`, `contains(s, sub)`, `starts with(s, prefix)`, `ends with(s, suffix)`, `upper case(s)`, `lower case(s)`, `substring(s, start)`, `substring(s, start, length)` |
| Boolean | `not(b)` |
| Null | `is null(v)` |

## Architecture

- `RodarFeel` — public API (`eval/2`)
- `RodarFeel.Parser` — NimbleParsec-based parser producing AST tuples
- `RodarFeel.Evaluator` — tree-walking evaluator
- `RodarFeel.Functions` — built-in function dispatch

## License

Apache-2.0. See [LICENSE.md](LICENSE.md).
