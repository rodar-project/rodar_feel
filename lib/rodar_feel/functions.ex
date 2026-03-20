defmodule RodarFeel.Functions do
  @moduledoc """
  Built-in FEEL function implementations.

  Dispatches on `{name_string, args_list}`. Implements null propagation:
  if any argument is `nil`, the result is `nil` (except for `is null`, `not`,
  `all`, `any`, and `string`).

  ## Supported functions

  - Numeric: `abs/1`, `floor/1`, `ceiling/1`, `round/1-2`, `min/1`, `max/1`,
    `sum/1`, `count/1`, `product/1`, `mean/1`
  - String: `string length/1`, `contains/2`, `starts with/2`, `ends with/2`,
    `upper case/1`, `lower case/1`, `substring/2-3`, `split/2`,
    `substring before/2`, `substring after/2`, `replace/3`, `trim/1`
  - Boolean: `not/1`, `all/1`, `any/1`
  - Null: `is null/1`
  - List: `append/2`, `concatenate/2+`, `reverse/1`, `flatten/1`,
    `distinct values/1`, `sort/1`, `index of/2`, `list contains/2`
  - Conversion: `string/1`

  ## Examples

      iex> RodarFeel.Functions.call("abs", [-5])
      {:ok, 5}

      iex> RodarFeel.Functions.call("string length", ["hello"])
      {:ok, 5}

      iex> RodarFeel.Functions.call("is null", [nil])
      {:ok, true}

      iex> RodarFeel.Functions.call("abs", [nil])
      {:ok, nil}

  """

  @doc """
  Call a FEEL built-in function by name with the given arguments.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec call(String.t(), [any()]) :: {:ok, any()} | {:error, String.t()}
  def call(name, args) do
    dispatch(name, args)
  end

  # --- Null check (no null propagation) ---
  defp dispatch("is null", [val]), do: {:ok, is_nil(val)}
  defp dispatch("is null", args), do: arity_error("is null", 1, args)

  # --- Boolean not (no null propagation for nil) ---
  defp dispatch("not", [nil]), do: {:ok, nil}
  defp dispatch("not", [val]) when is_boolean(val), do: {:ok, not val}
  defp dispatch("not", [_]), do: {:error, "not: argument must be boolean"}
  defp dispatch("not", args), do: arity_error("not", 1, args)

  # --- Boolean all/any (three-valued, no simple null propagation) ---
  defp dispatch("all", [nil]), do: {:ok, nil}

  defp dispatch("all", [list]) when is_list(list) do
    cond do
      Enum.any?(list, &(&1 == false)) -> {:ok, false}
      Enum.any?(list, &is_nil/1) -> {:ok, nil}
      true -> {:ok, true}
    end
  end

  defp dispatch("all", args), do: arity_error("all", 1, args)

  defp dispatch("any", [nil]), do: {:ok, nil}

  defp dispatch("any", [list]) when is_list(list) do
    cond do
      Enum.any?(list, &(&1 == true)) -> {:ok, true}
      Enum.any?(list, &is_nil/1) -> {:ok, nil}
      true -> {:ok, false}
    end
  end

  defp dispatch("any", args), do: arity_error("any", 1, args)

  # --- Numeric functions (with null propagation) ---
  defp dispatch("abs", [nil]), do: {:ok, nil}
  defp dispatch("abs", [n]) when is_number(n), do: {:ok, abs(n)}
  defp dispatch("abs", args), do: arity_error("abs", 1, args)

  defp dispatch("floor", [nil]), do: {:ok, nil}
  defp dispatch("floor", [n]) when is_number(n), do: {:ok, floor(n)}
  defp dispatch("floor", args), do: arity_error("floor", 1, args)

  defp dispatch("ceiling", [nil]), do: {:ok, nil}
  defp dispatch("ceiling", [n]) when is_number(n), do: {:ok, ceil(n)}
  defp dispatch("ceiling", args), do: arity_error("ceiling", 1, args)

  defp dispatch("round", [nil]), do: {:ok, nil}
  defp dispatch("round", [n]) when is_number(n), do: {:ok, round(n)}
  defp dispatch("round", [nil, _]), do: {:ok, nil}
  defp dispatch("round", [_, nil]), do: {:ok, nil}

  defp dispatch("round", [n, scale]) when is_number(n) and is_integer(scale) do
    factor = :math.pow(10, scale)
    {:ok, round(n * factor) / factor}
  end

  defp dispatch("round", args) when length(args) not in [1, 2] do
    arity_error("round", "1-2", args)
  end

  defp dispatch("min", [nil]), do: {:ok, nil}

  defp dispatch("min", [list]) when is_list(list) do
    if Enum.any?(list, &is_nil/1), do: {:ok, nil}, else: {:ok, Enum.min(list, fn -> nil end)}
  end

  defp dispatch("min", args), do: arity_error("min", 1, args)

  defp dispatch("max", [nil]), do: {:ok, nil}

  defp dispatch("max", [list]) when is_list(list) do
    if Enum.any?(list, &is_nil/1), do: {:ok, nil}, else: {:ok, Enum.max(list, fn -> nil end)}
  end

  defp dispatch("max", args), do: arity_error("max", 1, args)

  defp dispatch("sum", [nil]), do: {:ok, nil}

  defp dispatch("sum", [list]) when is_list(list) do
    if Enum.any?(list, &is_nil/1), do: {:ok, nil}, else: {:ok, Enum.sum(list)}
  end

  defp dispatch("sum", args), do: arity_error("sum", 1, args)

  defp dispatch("count", [nil]), do: {:ok, nil}
  defp dispatch("count", [list]) when is_list(list), do: {:ok, length(list)}
  defp dispatch("count", args), do: arity_error("count", 1, args)

  defp dispatch("product", [nil]), do: {:ok, nil}

  defp dispatch("product", [list]) when is_list(list) do
    if Enum.any?(list, &is_nil/1) do
      {:ok, nil}
    else
      {:ok, Enum.reduce(list, 1, &(&1 * &2))}
    end
  end

  defp dispatch("product", args), do: arity_error("product", 1, args)

  defp dispatch("mean", [nil]), do: {:ok, nil}

  defp dispatch("mean", [list]) when is_list(list) do
    cond do
      list == [] -> {:ok, nil}
      Enum.any?(list, &is_nil/1) -> {:ok, nil}
      true -> {:ok, Enum.sum(list) / length(list)}
    end
  end

  defp dispatch("mean", args), do: arity_error("mean", 1, args)

  # --- String functions (with null propagation) ---
  defp dispatch("string length", [nil]), do: {:ok, nil}
  defp dispatch("string length", [s]) when is_binary(s), do: {:ok, String.length(s)}
  defp dispatch("string length", args), do: arity_error("string length", 1, args)

  defp dispatch("contains", [nil, _]), do: {:ok, nil}
  defp dispatch("contains", [_, nil]), do: {:ok, nil}

  defp dispatch("contains", [s, sub]) when is_binary(s) and is_binary(sub) do
    {:ok, String.contains?(s, sub)}
  end

  defp dispatch("contains", args), do: arity_error("contains", 2, args)

  defp dispatch("starts with", [nil, _]), do: {:ok, nil}
  defp dispatch("starts with", [_, nil]), do: {:ok, nil}

  defp dispatch("starts with", [s, prefix]) when is_binary(s) and is_binary(prefix) do
    {:ok, String.starts_with?(s, prefix)}
  end

  defp dispatch("starts with", args), do: arity_error("starts with", 2, args)

  defp dispatch("ends with", [nil, _]), do: {:ok, nil}
  defp dispatch("ends with", [_, nil]), do: {:ok, nil}

  defp dispatch("ends with", [s, suffix]) when is_binary(s) and is_binary(suffix) do
    {:ok, String.ends_with?(s, suffix)}
  end

  defp dispatch("ends with", args), do: arity_error("ends with", 2, args)

  defp dispatch("upper case", [nil]), do: {:ok, nil}
  defp dispatch("upper case", [s]) when is_binary(s), do: {:ok, String.upcase(s)}
  defp dispatch("upper case", args), do: arity_error("upper case", 1, args)

  defp dispatch("lower case", [nil]), do: {:ok, nil}
  defp dispatch("lower case", [s]) when is_binary(s), do: {:ok, String.downcase(s)}
  defp dispatch("lower case", args), do: arity_error("lower case", 1, args)

  defp dispatch("substring", [nil | _]), do: {:ok, nil}
  defp dispatch("substring", [_, nil | _]), do: {:ok, nil}
  defp dispatch("substring", [_, _, nil]), do: {:ok, nil}

  defp dispatch("substring", [s, start]) when is_binary(s) and is_integer(start) do
    # FEEL substring is 1-based
    idx = if start > 0, do: start - 1, else: start
    {:ok, String.slice(s, idx..-1//1)}
  end

  defp dispatch("substring", [s, start, len])
       when is_binary(s) and is_integer(start) and is_integer(len) do
    idx = if start > 0, do: start - 1, else: start
    {:ok, String.slice(s, idx, len)}
  end

  defp dispatch("substring", args) when length(args) not in [2, 3] do
    arity_error("substring", "2-3", args)
  end

  defp dispatch("split", [nil, _]), do: {:ok, nil}
  defp dispatch("split", [_, nil]), do: {:ok, nil}

  defp dispatch("split", [s, delim]) when is_binary(s) and is_binary(delim) do
    {:ok, String.split(s, delim)}
  end

  defp dispatch("split", args), do: arity_error("split", 2, args)

  defp dispatch("substring before", [nil, _]), do: {:ok, nil}
  defp dispatch("substring before", [_, nil]), do: {:ok, nil}

  defp dispatch("substring before", [s, match]) when is_binary(s) and is_binary(match) do
    case String.split(s, match, parts: 2) do
      [before, _] -> {:ok, before}
      [_] -> {:ok, ""}
    end
  end

  defp dispatch("substring before", args), do: arity_error("substring before", 2, args)

  defp dispatch("substring after", [nil, _]), do: {:ok, nil}
  defp dispatch("substring after", [_, nil]), do: {:ok, nil}

  defp dispatch("substring after", [s, match]) when is_binary(s) and is_binary(match) do
    case String.split(s, match, parts: 2) do
      [_, after_part] -> {:ok, after_part}
      [_] -> {:ok, ""}
    end
  end

  defp dispatch("substring after", args), do: arity_error("substring after", 2, args)

  defp dispatch("replace", [nil, _, _]), do: {:ok, nil}
  defp dispatch("replace", [_, nil, _]), do: {:ok, nil}
  defp dispatch("replace", [_, _, nil]), do: {:ok, nil}

  defp dispatch("replace", [s, pattern, replacement])
       when is_binary(s) and is_binary(pattern) and is_binary(replacement) do
    {:ok, String.replace(s, pattern, replacement)}
  end

  defp dispatch("replace", args), do: arity_error("replace", 3, args)

  defp dispatch("trim", [nil]), do: {:ok, nil}
  defp dispatch("trim", [s]) when is_binary(s), do: {:ok, String.trim(s)}
  defp dispatch("trim", args), do: arity_error("trim", 1, args)

  # --- Conversion functions ---
  defp dispatch("string", [nil]), do: {:ok, nil}
  defp dispatch("string", [s]) when is_binary(s), do: {:ok, s}
  defp dispatch("string", [n]) when is_number(n), do: {:ok, to_string(n)}
  defp dispatch("string", [b]) when is_boolean(b), do: {:ok, to_string(b)}

  defp dispatch("string", [list]) when is_list(list) do
    inner = Enum.map_join(list, ", ", &format_value/1)
    {:ok, "[#{inner}]"}
  end

  defp dispatch("string", [%Date{} = d]), do: {:ok, Date.to_iso8601(d)}
  defp dispatch("string", [%Time{} = t]), do: {:ok, Time.to_iso8601(t)}
  defp dispatch("string", [%NaiveDateTime{} = ndt]), do: {:ok, NaiveDateTime.to_iso8601(ndt)}

  defp dispatch("string", [%RodarFeel.Duration{} = d]) do
    {:ok, format_duration(d)}
  end

  defp dispatch("string", [map]) when is_map(map) do
    inner =
      map
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{format_value(v)}" end)

    {:ok, "{#{inner}}"}
  end

  defp dispatch("string", args), do: arity_error("string", 1, args)

  # --- List functions ---
  defp dispatch("append", [nil, _]), do: {:ok, nil}

  defp dispatch("append", [list, item]) when is_list(list) do
    {:ok, list ++ [item]}
  end

  defp dispatch("append", args), do: arity_error("append", 2, args)

  defp dispatch("concatenate", args) when is_list(args) and length(args) >= 2 do
    if Enum.any?(args, &is_nil/1) do
      {:ok, nil}
    else
      if Enum.all?(args, &is_list/1) do
        {:ok, Enum.concat(args)}
      else
        {:error, "concatenate: all arguments must be lists"}
      end
    end
  end

  defp dispatch("concatenate", args), do: arity_error("concatenate", "2+", args)

  defp dispatch("reverse", [nil]), do: {:ok, nil}
  defp dispatch("reverse", [list]) when is_list(list), do: {:ok, Enum.reverse(list)}
  defp dispatch("reverse", args), do: arity_error("reverse", 1, args)

  defp dispatch("flatten", [nil]), do: {:ok, nil}
  defp dispatch("flatten", [list]) when is_list(list), do: {:ok, List.flatten(list)}
  defp dispatch("flatten", args), do: arity_error("flatten", 1, args)

  defp dispatch("distinct values", [nil]), do: {:ok, nil}
  defp dispatch("distinct values", [list]) when is_list(list), do: {:ok, Enum.uniq(list)}
  defp dispatch("distinct values", args), do: arity_error("distinct values", 1, args)

  defp dispatch("sort", [nil]), do: {:ok, nil}
  defp dispatch("sort", [list]) when is_list(list), do: {:ok, Enum.sort(list)}
  defp dispatch("sort", args), do: arity_error("sort", 1, args)

  defp dispatch("index of", [nil, _]), do: {:ok, nil}
  defp dispatch("index of", [_, nil]), do: {:ok, nil}

  defp dispatch("index of", [list, match]) when is_list(list) do
    indices =
      list
      |> Enum.with_index(1)
      |> Enum.filter(fn {elem, _idx} -> elem == match end)
      |> Enum.map(&elem(&1, 1))

    {:ok, indices}
  end

  defp dispatch("index of", args), do: arity_error("index of", 2, args)

  defp dispatch("list contains", [nil, _]), do: {:ok, nil}

  defp dispatch("list contains", [list, element]) when is_list(list) do
    {:ok, Enum.member?(list, element)}
  end

  defp dispatch("list contains", args), do: arity_error("list contains", 2, args)

  # --- Temporal construction functions ---

  defp dispatch("date", [nil]), do: {:ok, nil}

  defp dispatch("date", [s]) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> {:ok, d}
      _ -> {:error, "date: invalid date string #{inspect(s)}"}
    end
  end

  defp dispatch("date", [nil, _, _]), do: {:ok, nil}
  defp dispatch("date", [_, nil, _]), do: {:ok, nil}
  defp dispatch("date", [_, _, nil]), do: {:ok, nil}

  defp dispatch("date", [y, m, d]) when is_integer(y) and is_integer(m) and is_integer(d) do
    case Date.new(y, m, d) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "date: invalid date #{y}-#{m}-#{d}"}
    end
  end

  defp dispatch("date", args) when length(args) not in [1, 3] do
    arity_error("date", "1 or 3", args)
  end

  defp dispatch("time", [nil]), do: {:ok, nil}

  defp dispatch("time", [s]) when is_binary(s) do
    case Time.from_iso8601(s) do
      {:ok, t} -> {:ok, t}
      _ -> {:error, "time: invalid time string #{inspect(s)}"}
    end
  end

  defp dispatch("time", [nil, _, _]), do: {:ok, nil}
  defp dispatch("time", [_, nil, _]), do: {:ok, nil}
  defp dispatch("time", [_, _, nil]), do: {:ok, nil}

  defp dispatch("time", [h, m, s]) when is_integer(h) and is_integer(m) and is_integer(s) do
    case Time.new(h, m, s) do
      {:ok, t} -> {:ok, t}
      _ -> {:error, "time: invalid time #{h}:#{m}:#{s}"}
    end
  end

  defp dispatch("time", args) when length(args) not in [1, 3] do
    arity_error("time", "1 or 3", args)
  end

  defp dispatch("date and time", [nil]), do: {:ok, nil}

  defp dispatch("date and time", [s]) when is_binary(s) do
    case NaiveDateTime.from_iso8601(s) do
      {:ok, ndt} -> {:ok, ndt}
      _ -> {:error, "date and time: invalid datetime string #{inspect(s)}"}
    end
  end

  defp dispatch("date and time", [nil, _]), do: {:ok, nil}
  defp dispatch("date and time", [_, nil]), do: {:ok, nil}

  defp dispatch("date and time", [%Date{} = d, %Time{} = t]) do
    {:ok, NaiveDateTime.new!(d, t)}
  end

  defp dispatch("date and time", args) when length(args) not in [1, 2] do
    arity_error("date and time", "1 or 2", args)
  end

  defp dispatch("duration", [nil]), do: {:ok, nil}

  defp dispatch("duration", [s]) when is_binary(s) do
    alias RodarFeel.Duration
    Duration.parse(s)
  end

  defp dispatch("duration", args), do: arity_error("duration", 1, args)

  defp dispatch("now", []) do
    {:ok, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}
  end

  defp dispatch("today", []) do
    {:ok, Date.utc_today()}
  end

  # --- Number parsing ---
  defp dispatch("number", [nil]), do: {:ok, nil}

  defp dispatch("number", [s]) when is_binary(s) do
    case parse_number_string(s) do
      {:ok, n} -> {:ok, n}
      :error -> {:error, "number: cannot parse #{inspect(s)}"}
    end
  end

  defp dispatch("number", [nil, _, _]), do: {:ok, nil}
  defp dispatch("number", [_, nil, _]), do: {:ok, nil}
  defp dispatch("number", [_, _, nil]), do: {:ok, nil}

  defp dispatch("number", [s, grouping, decimal])
       when is_binary(s) and is_binary(grouping) and is_binary(decimal) do
    # Remove grouping separators, replace decimal separator with "."
    cleaned =
      s
      |> String.replace(grouping, "")
      |> String.replace(decimal, ".")

    case parse_number_string(cleaned) do
      {:ok, n} ->
        {:ok, n}

      :error ->
        {:error,
         "number: cannot parse #{inspect(s)} with grouping=#{inspect(grouping)}, decimal=#{inspect(decimal)}"}
    end
  end

  defp dispatch("number", args) when length(args) not in [1, 3] do
    arity_error("number", "1 or 3", args)
  end

  # --- Statistical functions ---
  defp dispatch("median", [nil]), do: {:ok, nil}

  defp dispatch("median", [list]) when is_list(list) do
    cond do
      list == [] ->
        {:ok, nil}

      Enum.any?(list, &is_nil/1) ->
        {:ok, nil}

      true ->
        sorted = Enum.sort(list)
        len = length(sorted)
        mid = div(len, 2)

        if rem(len, 2) == 1 do
          {:ok, Enum.at(sorted, mid)}
        else
          {:ok, (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2}
        end
    end
  end

  defp dispatch("median", args), do: arity_error("median", 1, args)

  defp dispatch("stddev", [nil]), do: {:ok, nil}

  defp dispatch("stddev", [list]) when is_list(list) do
    cond do
      length(list) < 2 ->
        {:ok, nil}

      Enum.any?(list, &is_nil/1) ->
        {:ok, nil}

      true ->
        n = length(list)
        mean = Enum.sum(list) / n
        variance = Enum.reduce(list, 0, fn x, acc -> acc + (x - mean) ** 2 end) / (n - 1)
        {:ok, :math.sqrt(variance)}
    end
  end

  defp dispatch("stddev", args), do: arity_error("stddev", 1, args)

  defp dispatch("mode", [nil]), do: {:ok, nil}

  defp dispatch("mode", [list]) when is_list(list) do
    cond do
      list == [] ->
        {:ok, []}

      Enum.any?(list, &is_nil/1) ->
        {:ok, nil}

      true ->
        freqs = Enum.frequencies(list)
        max_freq = freqs |> Map.values() |> Enum.max()

        modes =
          freqs
          |> Enum.filter(fn {_, f} -> f == max_freq end)
          |> Enum.map(&elem(&1, 0))
          |> Enum.sort()

        {:ok, modes}
    end
  end

  defp dispatch("mode", args), do: arity_error("mode", 1, args)

  # --- Random ---
  defp dispatch("random", []), do: {:ok, :rand.uniform()}

  # --- Regex matching ---
  defp dispatch("matches", [nil, _]), do: {:ok, nil}
  defp dispatch("matches", [_, nil]), do: {:ok, nil}

  defp dispatch("matches", [s, pattern]) when is_binary(s) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> {:ok, Regex.match?(regex, s)}
      {:error, _} -> {:error, "matches: invalid regex pattern #{inspect(pattern)}"}
    end
  end

  defp dispatch("matches", args), do: arity_error("matches", 2, args)

  # --- String join ---
  defp dispatch("string join", [nil]), do: {:ok, nil}
  defp dispatch("string join", [nil, _]), do: {:ok, nil}

  defp dispatch("string join", [list]) when is_list(list) do
    if Enum.any?(list, &(not is_binary(&1) and not is_nil(&1))) do
      {:error, "string join: all elements must be strings"}
    else
      {:ok, list |> Enum.reject(&is_nil/1) |> Enum.join()}
    end
  end

  defp dispatch("string join", [list, delim]) when is_list(list) and is_binary(delim) do
    if Enum.any?(list, &(not is_binary(&1) and not is_nil(&1))) do
      {:error, "string join: all elements must be strings"}
    else
      {:ok, list |> Enum.reject(&is_nil/1) |> Enum.join(delim)}
    end
  end

  defp dispatch("string join", args) when length(args) not in [1, 2] do
    arity_error("string join", "1 or 2", args)
  end

  # --- Unknown function ---
  defp dispatch(name, _args) do
    {:error, "unknown FEEL function: #{name}"}
  end

  defp arity_error(name, expected, args) do
    {:error, "#{name}: expected #{expected} argument(s), got #{length(args)}"}
  end

  defp format_value(nil), do: "null"
  defp format_value(s) when is_binary(s), do: "\"#{s}\""
  defp format_value(b) when is_boolean(b), do: to_string(b)
  defp format_value(n) when is_number(n), do: to_string(n)

  defp format_value(list) when is_list(list) do
    inner = Enum.map_join(list, ", ", &format_value/1)
    "[#{inner}]"
  end

  defp format_value(%Date{} = d), do: Date.to_iso8601(d)
  defp format_value(%Time{} = t), do: Time.to_iso8601(t)
  defp format_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp format_value(%RodarFeel.Duration{} = d), do: format_duration(d)
  defp format_value(other), do: inspect(other)

  defp format_duration(%RodarFeel.Duration{} = d) do
    date_part =
      [
        if(d.years != 0, do: "#{d.years}Y"),
        if(d.months != 0, do: "#{d.months}M"),
        if(d.days != 0, do: "#{d.days}D")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join()

    time_part =
      [
        if(d.hours != 0, do: "#{d.hours}H"),
        if(d.minutes != 0, do: "#{d.minutes}M"),
        if(d.seconds != 0, do: "#{format_seconds(d.seconds)}S")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join()

    case {date_part, time_part} do
      {"", ""} -> "PT0S"
      {dp, ""} -> "P#{dp}"
      {"", tp} -> "PT#{tp}"
      {dp, tp} -> "P#{dp}T#{tp}"
    end
  end

  defp format_seconds(s) when is_float(s), do: :erlang.float_to_binary(s, decimals: 1)
  defp format_seconds(s), do: Integer.to_string(s)

  defp parse_number_string(s) do
    case Float.parse(s) do
      {f, ""} ->
        # Return integer if no fractional part
        if trunc(f) == f and not String.contains?(s, "."), do: {:ok, trunc(f)}, else: {:ok, f}

      _ ->
        case Integer.parse(s) do
          {n, ""} -> {:ok, n}
          _ -> :error
        end
    end
  end
end
