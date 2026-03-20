defmodule RodarFeel do
  @moduledoc """
  FEEL (Friendly Enough Expression Language) evaluator for BPMN 2.0 and DMN.

  FEEL is the standard expression language for BPMN and DMN. This module
  provides a complete FEEL implementation with:

  - 48 built-in functions (numeric, string, list, boolean, temporal, statistical)
  - Temporal types with timezone support (Date, Time, DateTime, Duration)
  - DMN unary tests for decision table cells
  - Null propagation and three-valued boolean logic
  - User-defined functions (lambdas) with closures
  - `instance of` type checking

  ## API

  - `eval/2` — evaluate a FEEL expression against bindings
  - `eval_unary/3` — evaluate a DMN unary test against an input value

  Bindings receive the raw data map directly. FEEL users write `count > 5`,
  not `data["count"] > 5`. Top-level identifiers resolve against the bindings map.

  ## Examples

      iex> RodarFeel.eval("1 + 2", %{})
      {:ok, 3}

      iex> RodarFeel.eval("amount > 1000", %{"amount" => 1500})
      {:ok, true}

      iex> RodarFeel.eval("null", %{})
      {:ok, nil}

      iex> RodarFeel.eval("if x > 10 then \"high\" else \"low\"", %{"x" => 15})
      {:ok, "high"}

  """

  alias RodarFeel.Evaluator
  alias RodarFeel.Parser

  @doc """
  Parse and evaluate a FEEL expression string against the given bindings.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      iex> RodarFeel.eval("2 * 3 + 1", %{})
      {:ok, 7}

      iex> RodarFeel.eval("name", %{"name" => "Alice"})
      {:ok, "Alice"}

  """
  @spec eval(String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  def eval(expr, bindings) do
    with {:ok, ast} <- Parser.parse(expr) do
      Evaluator.evaluate(ast, bindings)
    end
  end

  @doc """
  Parse and evaluate a DMN unary test against an input value.

  Unary tests are expressions used in DMN decision table cells.
  They are evaluated against an implicit input value.

  ## Supported syntax

  - `-` — wildcard, matches anything
  - `< 100`, `>= 5`, `= "foo"` — comparison test
  - `[1..5]` — inclusive range
  - `(1..5)` — exclusive range
  - `[1..5)`, `(1..5]` — half-open ranges
  - `not(< 100)` — negated test
  - `1, 2, 3` — disjunction (match any)
  - `42` — equality test (plain value)

  ## Examples

      iex> RodarFeel.eval_unary("< 100", 50, %{})
      {:ok, true}

      iex> RodarFeel.eval_unary("[1..5]", 3, %{})
      {:ok, true}

      iex> RodarFeel.eval_unary("1, 2, 3", 2, %{})
      {:ok, true}

      iex> RodarFeel.eval_unary("-", :anything, %{})
      {:ok, true}

  """
  @spec eval_unary(String.t(), any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  def eval_unary(test, input, bindings \\ %{}) do
    with {:ok, ast} <- Parser.parse_unary(test) do
      Evaluator.evaluate_unary(ast, input, bindings)
    end
  end
end
