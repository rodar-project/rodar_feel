defmodule RodarFeel.Evaluator do
  @moduledoc """
  Tree-walking evaluator for FEEL AST nodes.

  Implements FEEL semantics including null propagation, three-valued boolean
  logic, and string concatenation via `+`.

  ## Key behaviors

  - **Null propagation:** `nil + 1` evaluates to `nil`, `nil > 5` evaluates to `false`
  - **Three-valued boolean:** `true and nil` evaluates to `nil`, `false and nil` evaluates to `false`
  - **String `+`:** If both operands are strings, concatenate; if both are numbers, add
  - **Path resolution:** `order.status` resolves to `bindings["order"]["status"]`
  - **`in` operator:** Check list membership or range inclusion
  - **`between` operator:** `x between a and b` is `a <= x and x <= b`
  - **Bracket access:** `a["key"]` resolves `a` then accesses string key
  - **Context literals:** `{a: 1, b: 2}` evaluates to `%{"a" => 1, "b" => 2}`
  - **For-in-return:** `for x in list return x + 1` iterates and collects results
  - **Quantified:** `some/every x in list satisfies condition`

  ## Examples

      iex> alias RodarFeel.Evaluator
      iex> Evaluator.evaluate({:literal, 42}, %{})
      {:ok, 42}

      iex> alias RodarFeel.Evaluator
      iex> Evaluator.evaluate({:binop, :+, {:literal, 1}, {:literal, 2}}, %{})
      {:ok, 3}

      iex> alias RodarFeel.Evaluator
      iex> Evaluator.evaluate({:path, ["x"]}, %{"x" => 10})
      {:ok, 10}

  """

  alias RodarFeel.Duration
  alias RodarFeel.Functions

  @doc """
  Evaluate a FEEL AST node against the given bindings map.

  Returns `{:ok, value}` or `{:error, reason}`.
  """
  @spec evaluate(tuple() | any(), map()) :: {:ok, any()} | {:error, String.t()}
  def evaluate(ast, bindings) when is_map(bindings) do
    eval_node(ast, bindings)
  rescue
    e -> {:error, "runtime error: #{Exception.message(e)}"}
  end

  @doc """
  Evaluate a unary test AST against an input value and bindings.

  Returns `{:ok, boolean}` or `{:error, reason}`.
  """
  @spec evaluate_unary(tuple(), any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  def evaluate_unary(ast, input, bindings) when is_map(bindings) do
    eval_unary_test(ast, input, bindings)
  rescue
    e -> {:error, "runtime error: #{Exception.message(e)}"}
  end

  defp eval_unary_test({:unary_wildcard}, _input, _bindings), do: {:ok, true}

  defp eval_unary_test({:unary_cmp, op, expr_ast}, input, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings) do
      eval_binop(op, input, val)
    end
  end

  defp eval_unary_test({:unary_value, expr_ast}, input, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings) do
      eval_binop(:==, input, val)
    end
  end

  defp eval_unary_test({:unary_range, from_ast, to_ast, from_inc, to_inc}, input, bindings) do
    with {:ok, from} <- eval_node(from_ast, bindings),
         {:ok, to} <- eval_node(to_ast, bindings),
         {:ok, from_ok} <- eval_binop(if(from_inc, do: :>=, else: :>), input, from),
         {:ok, to_ok} <- eval_binop(if(to_inc, do: :<=, else: :<), input, to) do
      {:ok, from_ok and to_ok}
    end
  end

  defp eval_unary_test({:unary_not, inner_ast}, input, bindings) do
    with {:ok, result} <- eval_unary_test(inner_ast, input, bindings) do
      {:ok, not result}
    end
  end

  defp eval_unary_test({:unary_disjunction, tests}, input, bindings) do
    eval_unary_disjunction(tests, input, bindings)
  end

  defp eval_unary_disjunction([], _input, _bindings), do: {:ok, false}

  defp eval_unary_disjunction([test | rest], input, bindings) do
    with {:ok, result} <- eval_unary_test(test, input, bindings) do
      if result, do: {:ok, true}, else: eval_unary_disjunction(rest, input, bindings)
    end
  end

  # --- Literals ---
  defp eval_node({:literal, value}, _bindings), do: {:ok, value}

  # --- Temporal literal ---
  defp eval_node({:temporal, str}, _bindings), do: resolve_temporal(str)

  # --- Temporal literal with property access ---
  defp eval_node({:temporal_path, temporal_ast, segments}, bindings) do
    with {:ok, value} <- eval_node(temporal_ast, bindings) do
      {:ok, resolve_remaining(segments, value)}
    end
  end

  # --- Path resolution ---
  defp eval_node({:path, segments}, bindings), do: {:ok, resolve_path(segments, bindings)}

  # --- Bracket access ---
  defp eval_node({:bracket, base, key_ast}, bindings) do
    with {:ok, base_val} <- eval_node(base, bindings),
         {:ok, key_val} <- eval_node(key_ast, bindings) do
      eval_bracket_access(base_val, key_val)
    end
  end

  # --- List ---
  defp eval_node({:list, items}, bindings), do: eval_list(items, bindings, [])

  # --- Context literal ---
  defp eval_node({:context, entries}, bindings) do
    eval_context(entries, bindings, %{})
  end

  # --- If-then-else ---
  defp eval_node({:if, cond_ast, then_ast, else_ast}, bindings) do
    with {:ok, cond_val} <- eval_node(cond_ast, bindings) do
      if cond_val == true do
        eval_node(then_ast, bindings)
      else
        eval_node(else_ast, bindings)
      end
    end
  end

  # --- In operator ---
  defp eval_node({:in, expr_ast, collection_ast}, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings),
         {:ok, collection} <- eval_node(collection_ast, bindings) do
      eval_in(val, collection)
    end
  end

  # --- Between operator ---
  defp eval_node({:between, expr_ast, low_ast, high_ast}, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings),
         {:ok, low} <- eval_node(low_ast, bindings),
         {:ok, high} <- eval_node(high_ast, bindings) do
      eval_between(val, low, high)
    end
  end

  # --- Range ---
  defp eval_node({:range, from_ast, to_ast}, bindings) do
    with {:ok, from} <- eval_node(from_ast, bindings),
         {:ok, to} <- eval_node(to_ast, bindings) do
      {:ok, {:range_value, from, to}}
    end
  end

  # --- For-in-return ---
  defp eval_node({:for, iterations, body}, bindings) do
    eval_for(iterations, body, bindings)
  end

  # --- Quantified expressions ---
  defp eval_node({:some, iterations, condition}, bindings) do
    eval_some(iterations, condition, bindings)
  end

  defp eval_node({:every, iterations, condition}, bindings) do
    eval_every(iterations, condition, bindings)
  end

  # --- Unary operators ---
  defp eval_node({:unary, :-, expr_ast}, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings) do
      eval_unary_neg(val)
    end
  end

  defp eval_node({:unary, :not, expr_ast}, bindings) do
    with {:ok, val} <- eval_node(expr_ast, bindings) do
      eval_unary_not(val)
    end
  end

  # --- Binary operators ---
  defp eval_node({:binop, :and, left_ast, right_ast}, bindings) do
    eval_and(left_ast, right_ast, bindings)
  end

  defp eval_node({:binop, :or, left_ast, right_ast}, bindings) do
    eval_or(left_ast, right_ast, bindings)
  end

  defp eval_node({:binop, op, left_ast, right_ast}, bindings) do
    with {:ok, left} <- eval_node(left_ast, bindings),
         {:ok, right} <- eval_node(right_ast, bindings) do
      eval_binop(op, left, right)
    end
  end

  # --- Function calls ---
  defp eval_node({:funcall, name, arg_asts}, bindings) do
    with {:ok, args} <- eval_args(arg_asts, bindings, []) do
      Functions.call(name, args)
    end
  end

  # --- Helpers ---

  defp resolve_path([], _map), do: nil

  defp resolve_path([segment | rest], map) when is_map(map) do
    value = Map.get(map, segment)
    resolve_remaining(rest, value)
  end

  defp resolve_path(_segments, _non_map), do: nil

  defp resolve_remaining([], value), do: value

  defp resolve_remaining([segment | rest], value) do
    case temporal_property(value, segment) do
      {:ok, prop} ->
        resolve_remaining(rest, prop)

      :not_temporal when is_map(value) ->
        resolve_remaining(rest, Map.get(value, segment))

      :not_temporal ->
        nil
    end
  end

  defp eval_bracket_access(nil, _key), do: {:ok, nil}

  defp eval_bracket_access(map, key) when is_map(map) do
    {:ok, Map.get(map, to_string(key))}
  end

  defp eval_bracket_access(list, index) when is_list(list) and is_integer(index) do
    {:ok, Enum.at(list, index)}
  end

  defp eval_bracket_access(_base, _key), do: {:ok, nil}

  defp eval_list([], _bindings, acc), do: {:ok, Enum.reverse(acc)}

  defp eval_list([item | rest], bindings, acc) do
    with {:ok, val} <- eval_node(item, bindings) do
      eval_list(rest, bindings, [val | acc])
    end
  end

  defp eval_args([], _bindings, acc), do: {:ok, Enum.reverse(acc)}

  defp eval_args([arg | rest], bindings, acc) do
    with {:ok, val} <- eval_node(arg, bindings) do
      eval_args(rest, bindings, [val | acc])
    end
  end

  # --- Context evaluation ---
  defp eval_context([], _bindings, acc), do: {:ok, acc}

  defp eval_context([{key, expr} | rest], bindings, acc) do
    with {:ok, val} <- eval_node(expr, Map.merge(bindings, acc)) do
      eval_context(rest, bindings, Map.put(acc, key, val))
    end
  end

  # --- Between evaluation ---
  defp eval_between(nil, _low, _high), do: {:ok, nil}
  defp eval_between(_val, nil, _high), do: {:ok, nil}
  defp eval_between(_val, _low, nil), do: {:ok, nil}

  defp eval_between(val, low, high) do
    {:ok, val >= low and val <= high}
  end

  # --- For-in-return evaluation ---
  defp eval_for(iterations, body, bindings) do
    eval_for_loop(iterations, body, bindings, [bindings])
  end

  defp eval_for_loop([], body, _bindings, binding_sets) do
    results =
      Enum.flat_map(binding_sets, fn b ->
        case eval_node(body, b) do
          {:ok, val} -> [val]
          _ -> []
        end
      end)

    {:ok, results}
  end

  defp eval_for_loop([{var, collection_ast} | rest], body, bindings, binding_sets) do
    new_binding_sets = expand_binding_sets(binding_sets, var, collection_ast)
    eval_for_loop(rest, body, bindings, new_binding_sets)
  end

  # --- Quantified expression evaluation ---
  defp eval_some(iterations, condition, bindings) do
    eval_some_loop(iterations, condition, bindings, [bindings])
  end

  defp eval_some_loop([], condition, _bindings, binding_sets) do
    results = collect_condition_results(binding_sets, condition)

    cond do
      Enum.any?(results, &(&1 == true)) -> {:ok, true}
      Enum.any?(results, &is_nil/1) -> {:ok, nil}
      true -> {:ok, false}
    end
  end

  defp eval_some_loop([{var, collection_ast} | rest], condition, bindings, binding_sets) do
    new_binding_sets = expand_binding_sets(binding_sets, var, collection_ast)
    eval_some_loop(rest, condition, bindings, new_binding_sets)
  end

  defp eval_every(iterations, condition, bindings) do
    eval_every_loop(iterations, condition, bindings, [bindings])
  end

  defp eval_every_loop([], condition, _bindings, binding_sets) do
    results = collect_condition_results(binding_sets, condition)

    cond do
      Enum.any?(results, &(&1 == false)) -> {:ok, false}
      Enum.any?(results, &is_nil/1) -> {:ok, nil}
      true -> {:ok, true}
    end
  end

  defp eval_every_loop([{var, collection_ast} | rest], condition, bindings, binding_sets) do
    new_binding_sets = expand_binding_sets(binding_sets, var, collection_ast)
    eval_every_loop(rest, condition, bindings, new_binding_sets)
  end

  defp expand_binding_sets(binding_sets, var, collection_ast) do
    Enum.flat_map(binding_sets, fn b ->
      expand_single_binding(b, var, collection_ast)
    end)
  end

  defp expand_single_binding(b, var, collection_ast) do
    case eval_node(collection_ast, b) do
      {:ok, list} when is_list(list) ->
        Enum.map(list, fn item -> Map.put(b, var, item) end)

      _ ->
        []
    end
  end

  defp collect_condition_results(binding_sets, condition) do
    Enum.map(binding_sets, fn b ->
      case eval_node(condition, b) do
        {:ok, val} -> val
        _ -> nil
      end
    end)
  end

  # --- Unary helpers ---

  defp eval_unary_neg(nil), do: {:ok, nil}
  defp eval_unary_neg(n) when is_number(n), do: {:ok, -n}
  defp eval_unary_neg(_), do: {:error, "unary -: operand must be a number"}

  defp eval_unary_not(nil), do: {:ok, nil}
  defp eval_unary_not(true), do: {:ok, false}
  defp eval_unary_not(false), do: {:ok, true}
  defp eval_unary_not(_), do: {:error, "not: operand must be boolean"}

  # --- Three-valued boolean logic ---

  defp eval_and(left_ast, right_ast, bindings) do
    with {:ok, left} <- eval_node(left_ast, bindings) do
      case left do
        false -> {:ok, false}
        true -> eval_node(right_ast, bindings)
        nil -> eval_and_nil(right_ast, bindings)
      end
    end
  end

  defp eval_and_nil(right_ast, bindings) do
    with {:ok, right} <- eval_node(right_ast, bindings) do
      case right do
        false -> {:ok, false}
        _ -> {:ok, nil}
      end
    end
  end

  defp eval_or(left_ast, right_ast, bindings) do
    with {:ok, left} <- eval_node(left_ast, bindings) do
      case left do
        true -> {:ok, true}
        false -> eval_node(right_ast, bindings)
        nil -> eval_or_nil(right_ast, bindings)
      end
    end
  end

  defp eval_or_nil(right_ast, bindings) do
    with {:ok, right} <- eval_node(right_ast, bindings) do
      case right do
        true -> {:ok, true}
        _ -> {:ok, nil}
      end
    end
  end

  # --- Binary operator dispatch ---

  # Equality always works (including nil)
  defp eval_binop(:==, left, right), do: {:ok, left == right}
  defp eval_binop(:!=, left, right), do: {:ok, left != right}

  # Both nil for non-equality ops
  defp eval_binop(_op, nil, nil), do: {:ok, nil}

  # Comparison with nil returns false
  defp eval_binop(op, nil, _right) when op in [:<, :>, :<=, :>=], do: {:ok, false}
  defp eval_binop(op, _left, nil) when op in [:<, :>, :<=, :>=], do: {:ok, false}

  # Arithmetic with nil propagates nil
  defp eval_binop(op, nil, _right) when op in [:+, :-, :*, :/, :%, :**], do: {:ok, nil}
  defp eval_binop(op, _left, nil) when op in [:+, :-, :*, :/, :%, :**], do: {:ok, nil}

  # Arithmetic
  defp eval_binop(:+, l, r) when is_number(l) and is_number(r), do: {:ok, l + r}
  defp eval_binop(:+, l, r) when is_binary(l) and is_binary(r), do: {:ok, l <> r}
  defp eval_binop(:-, l, r) when is_number(l) and is_number(r), do: {:ok, l - r}
  defp eval_binop(:*, l, r) when is_number(l) and is_number(r), do: {:ok, l * r}

  defp eval_binop(:/, _l, 0), do: {:error, "division by zero"}
  defp eval_binop(:/, _l, +0.0), do: {:error, "division by zero"}
  defp eval_binop(:/, l, r) when is_number(l) and is_number(r), do: {:ok, l / r}

  defp eval_binop(:%, _l, 0), do: {:error, "modulo by zero"}

  defp eval_binop(:%, l, r) when is_integer(l) and is_integer(r) do
    {:ok, rem(l, r)}
  end

  defp eval_binop(:**, l, r) when is_number(l) and is_number(r) do
    {:ok, :math.pow(l, r)}
  end

  # Comparison
  defp eval_binop(:<, l, r), do: eval_cmp(:<, l, r)
  defp eval_binop(:>, l, r), do: eval_cmp(:>, l, r)
  defp eval_binop(:<=, l, r), do: eval_cmp(:<=, l, r)
  defp eval_binop(:>=, l, r), do: eval_cmp(:>=, l, r)

  # Temporal arithmetic (date ± duration, date - date, etc.)
  defp eval_binop(op, l, r) when op in [:+, :-] do
    case eval_temporal_binop(op, l, r) do
      :not_temporal -> {:error, "unsupported binop: #{op}"}
      result -> result
    end
  end

  defp eval_binop(op, _l, _r), do: {:error, "unsupported binop: #{op}"}

  # Comparison with temporal fallback
  defp eval_cmp(op, l, r) do
    case eval_temporal_cmp(op, l, r) do
      :not_temporal -> {:ok, apply(Kernel, op, [l, r])}
      result -> result
    end
  end

  # --- In operator ---

  defp eval_in(nil, _collection), do: {:ok, nil}
  defp eval_in(_val, nil), do: {:ok, nil}

  defp eval_in(val, {:range_value, from, to}) when is_number(val) do
    {:ok, val >= from and val <= to}
  end

  defp eval_in(val, list) when is_list(list) do
    {:ok, Enum.member?(list, val)}
  end

  defp eval_in(_val, _other), do: {:ok, false}

  # --- Temporal literal resolution ---
  # Tries date, time, naive datetime, then duration — first successful parse wins.

  defp resolve_temporal(str) do
    with :error <- try_date(str),
         :error <- try_time(str),
         :error <- try_naive_datetime(str),
         :error <- try_duration(str) do
      {:error, "invalid temporal literal: @\"#{str}\""}
    end
  end

  defp try_date(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end

  defp try_time(str) do
    case Time.from_iso8601(str) do
      {:ok, t} -> {:ok, t}
      _ -> :error
    end
  end

  defp try_naive_datetime(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, ndt} -> {:ok, ndt}
      _ -> :error
    end
  end

  defp try_duration(str) do
    case Duration.parse(str) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end

  # --- Temporal property access ---
  # Extends resolve_remaining to handle .year, .month, etc. on temporal values.

  defp temporal_property(%Date{} = d, "year"), do: {:ok, d.year}
  defp temporal_property(%Date{} = d, "month"), do: {:ok, d.month}
  defp temporal_property(%Date{} = d, "day"), do: {:ok, d.day}

  defp temporal_property(%Time{} = t, "hour"), do: {:ok, t.hour}
  defp temporal_property(%Time{} = t, "minute"), do: {:ok, t.minute}
  defp temporal_property(%Time{} = t, "second"), do: {:ok, t.second}

  defp temporal_property(%NaiveDateTime{} = ndt, "year"), do: {:ok, ndt.year}
  defp temporal_property(%NaiveDateTime{} = ndt, "month"), do: {:ok, ndt.month}
  defp temporal_property(%NaiveDateTime{} = ndt, "day"), do: {:ok, ndt.day}
  defp temporal_property(%NaiveDateTime{} = ndt, "hour"), do: {:ok, ndt.hour}
  defp temporal_property(%NaiveDateTime{} = ndt, "minute"), do: {:ok, ndt.minute}
  defp temporal_property(%NaiveDateTime{} = ndt, "second"), do: {:ok, ndt.second}

  defp temporal_property(%Duration{} = d, "years"), do: {:ok, d.years}
  defp temporal_property(%Duration{} = d, "months"), do: {:ok, d.months}
  defp temporal_property(%Duration{} = d, "days"), do: {:ok, d.days}
  defp temporal_property(%Duration{} = d, "hours"), do: {:ok, d.hours}
  defp temporal_property(%Duration{} = d, "minutes"), do: {:ok, d.minutes}
  defp temporal_property(%Duration{} = d, "seconds"), do: {:ok, d.seconds}

  defp temporal_property(_, _), do: :not_temporal

  # --- Temporal arithmetic helpers ---

  defp eval_temporal_binop(:+, %Date{} = d, %Duration{} = dur),
    do: {:ok, add_duration_to_date(d, dur)}

  defp eval_temporal_binop(:+, %Duration{} = dur, %Date{} = d),
    do: {:ok, add_duration_to_date(d, dur)}

  defp eval_temporal_binop(:-, %Date{} = d, %Duration{} = dur) do
    {:ok, add_duration_to_date(d, Duration.negate(dur))}
  end

  defp eval_temporal_binop(:-, %Date{} = a, %Date{} = b) do
    {:ok, %Duration{days: Date.diff(a, b)}}
  end

  defp eval_temporal_binop(:+, %Time{} = t, %Duration{} = dur),
    do: {:ok, add_duration_to_time(t, dur)}

  defp eval_temporal_binop(:+, %Duration{} = dur, %Time{} = t),
    do: {:ok, add_duration_to_time(t, dur)}

  defp eval_temporal_binop(:-, %Time{} = t, %Duration{} = dur) do
    {:ok, add_duration_to_time(t, Duration.negate(dur))}
  end

  defp eval_temporal_binop(:-, %Time{} = a, %Time{} = b) do
    diff = Time.diff(a, b, :second)
    {:ok, seconds_to_duration(diff)}
  end

  defp eval_temporal_binop(:+, %NaiveDateTime{} = ndt, %Duration{} = dur) do
    {:ok, add_duration_to_naive(ndt, dur)}
  end

  defp eval_temporal_binop(:+, %Duration{} = dur, %NaiveDateTime{} = ndt) do
    {:ok, add_duration_to_naive(ndt, dur)}
  end

  defp eval_temporal_binop(:-, %NaiveDateTime{} = ndt, %Duration{} = dur) do
    {:ok, add_duration_to_naive(ndt, Duration.negate(dur))}
  end

  defp eval_temporal_binop(:-, %NaiveDateTime{} = a, %NaiveDateTime{} = b) do
    diff = NaiveDateTime.diff(a, b, :second)
    {:ok, seconds_to_duration(diff)}
  end

  defp eval_temporal_binop(:+, %Duration{} = a, %Duration{} = b), do: {:ok, Duration.add(a, b)}

  defp eval_temporal_binop(:-, %Duration{} = a, %Duration{} = b) do
    {:ok, Duration.add(a, Duration.negate(b))}
  end

  defp eval_temporal_binop(_, _, _), do: :not_temporal

  # --- Temporal comparison helpers ---

  defp eval_temporal_cmp(op, %Date{} = a, %Date{} = b),
    do: {:ok, date_cmp(op, Date.compare(a, b))}

  defp eval_temporal_cmp(op, %Time{} = a, %Time{} = b),
    do: {:ok, date_cmp(op, Time.compare(a, b))}

  defp eval_temporal_cmp(op, %NaiveDateTime{} = a, %NaiveDateTime{} = b) do
    {:ok, date_cmp(op, NaiveDateTime.compare(a, b))}
  end

  defp eval_temporal_cmp(op, %Duration{} = a, %Duration{} = b) do
    case Duration.compare(a, b) do
      :error -> {:error, "cannot compare mixed duration types"}
      result -> {:ok, date_cmp(op, result)}
    end
  end

  defp eval_temporal_cmp(_, _, _), do: :not_temporal

  defp date_cmp(:<, :lt), do: true
  defp date_cmp(:<, _), do: false
  defp date_cmp(:>, :gt), do: true
  defp date_cmp(:>, _), do: false
  defp date_cmp(:<=, :gt), do: false
  defp date_cmp(:<=, _), do: true
  defp date_cmp(:>=, :lt), do: false
  defp date_cmp(:>=, _), do: true

  # --- Date + Duration ---

  defp add_duration_to_date(date, %Duration{} = dur) do
    date
    |> shift_months(dur.years * 12 + dur.months)
    |> Date.add(dur.days)
  end

  defp shift_months(%Date{year: y, month: m, day: d}, months) do
    total = y * 12 + (m - 1) + months
    new_year = div(total, 12)
    new_month = rem(total, 12) + 1
    # Clamp day to valid range for the target month
    max_day = Calendar.ISO.days_in_month(new_year, new_month)
    Date.new!(new_year, new_month, min(d, max_day))
  end

  # --- Time + Duration ---

  defp add_duration_to_time(%Time{} = t, %Duration{} = dur) do
    seconds = Duration.to_seconds(dur)
    total = Time.diff(t, ~T[00:00:00], :second) + trunc(seconds)
    # Wrap around 24h
    wrapped = rem(rem(total, 86_400) + 86_400, 86_400)
    Time.add(~T[00:00:00], wrapped, :second)
  end

  # --- NaiveDateTime + Duration ---

  defp add_duration_to_naive(%NaiveDateTime{} = ndt, %Duration{} = dur) do
    # First apply year-month shift
    date = shift_months(NaiveDateTime.to_date(ndt), dur.years * 12 + dur.months)
    time = NaiveDateTime.to_time(ndt)
    {:ok, ndt2} = NaiveDateTime.new(date, time)
    # Then apply day-time shift
    day_time_seconds =
      dur.days * 86_400 + dur.hours * 3600 + dur.minutes * 60 + trunc(dur.seconds)

    NaiveDateTime.add(ndt2, day_time_seconds, :second)
  end

  defp seconds_to_duration(total_seconds) do
    abs_sec = abs(total_seconds)
    days = div(abs_sec, 86_400)
    remainder = rem(abs_sec, 86_400)
    hours = div(remainder, 3600)
    remainder = rem(remainder, 3600)
    minutes = div(remainder, 60)
    seconds = rem(remainder, 60)

    dur = %Duration{days: days, hours: hours, minutes: minutes, seconds: seconds}
    if total_seconds < 0, do: Duration.negate(dur), else: dur
  end
end
