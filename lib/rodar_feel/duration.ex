defmodule RodarFeel.Duration do
  @moduledoc """
  ISO 8601 duration representation for FEEL temporal arithmetic.

  FEEL distinguishes two duration subtypes:

  - **Years-and-months duration** — only `years` and `months` are set
  - **Days-and-time duration** — only `days`, `hours`, `minutes`, `seconds` are set

  Both subtypes use the same struct; the distinction is semantic. Construction
  functions ensure the invariant is maintained.
  """

  @type t :: %__MODULE__{
          years: integer(),
          months: integer(),
          days: integer(),
          hours: integer(),
          minutes: integer(),
          seconds: number()
        }

  defstruct years: 0, months: 0, days: 0, hours: 0, minutes: 0, seconds: 0

  @doc """
  Parse an ISO 8601 duration string into a `%Duration{}`.

  Supports formats like `P1Y2M3D`, `PT1H30M`, `P1Y2M3DT4H5M6S`, etc.

  Returns `{:ok, duration}` or `{:error, reason}`.

  ## Examples

      iex> RodarFeel.Duration.parse("P1Y2M")
      {:ok, %RodarFeel.Duration{years: 1, months: 2}}

      iex> RodarFeel.Duration.parse("PT1H30M")
      {:ok, %RodarFeel.Duration{hours: 1, minutes: 30}}

      iex> RodarFeel.Duration.parse("P1Y2M3DT4H5M6S")
      {:ok, %RodarFeel.Duration{years: 1, months: 2, days: 3, hours: 4, minutes: 5, seconds: 6}}

  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(str) when is_binary(str) do
    case parse_iso8601(str) do
      {:ok, dur} -> {:ok, dur}
      :error -> {:error, "invalid duration: #{inspect(str)}"}
    end
  end

  defp parse_iso8601(<<"P", rest::binary>>) do
    case parse_date_part(rest, %__MODULE__{}) do
      {:ok, dur, ""} -> {:ok, dur}
      {:ok, dur, <<"T", time_rest::binary>>} -> parse_time_part(time_rest, dur)
      _ -> :error
    end
  end

  defp parse_iso8601(_), do: :error

  defp parse_date_part(str, dur) do
    case consume_number(str) do
      {n, <<"Y", rest::binary>>} ->
        parse_date_part(rest, %{dur | years: n})

      {n, <<"M", rest::binary>>} ->
        parse_date_part(rest, %{dur | months: n})

      {n, <<"D", rest::binary>>} ->
        parse_date_part(rest, %{dur | days: n})

      {_n, _rest} ->
        :error

      nil ->
        {:ok, dur, str}
    end
  end

  defp parse_time_part(str, dur) do
    case consume_time_components(str, dur) do
      {:ok, dur, ""} -> {:ok, dur}
      _ -> :error
    end
  end

  defp consume_time_components("", dur), do: {:ok, dur, ""}

  defp consume_time_components(str, dur) do
    case consume_number(str) do
      {n, <<"H", rest::binary>>} ->
        consume_time_components(rest, %{dur | hours: n})

      {n, <<"M", rest::binary>>} ->
        consume_time_components(rest, %{dur | minutes: n})

      {n, <<"S", rest::binary>>} ->
        consume_time_components(rest, %{dur | seconds: n})

      _ ->
        :error
    end
  end

  defp consume_number(str) do
    case Integer.parse(str) do
      {n, <<".", rest::binary>>} ->
        case Integer.parse(rest) do
          {frac, suffix} ->
            digits = byte_size(rest) - byte_size(suffix)
            {n + frac / :math.pow(10, digits), suffix}

          :error ->
            {n, "." <> rest}
        end

      {n, rest} ->
        {n, rest}

      :error ->
        nil
    end
  end

  @doc """
  Returns true if this is a years-and-months duration (no day/time components).
  """
  @spec year_month?(t()) :: boolean()
  def year_month?(%__MODULE__{days: 0, hours: 0, minutes: 0, seconds: 0}), do: true
  def year_month?(%__MODULE__{}), do: false

  @doc """
  Returns true if this is a days-and-time duration (no year/month components).
  """
  @spec day_time?(t()) :: boolean()
  def day_time?(%__MODULE__{years: 0, months: 0}), do: true
  def day_time?(%__MODULE__{}), do: false

  @doc """
  Negate a duration (flip all component signs).
  """
  @spec negate(t()) :: t()
  def negate(%__MODULE__{} = d) do
    %__MODULE__{
      years: -d.years,
      months: -d.months,
      days: -d.days,
      hours: -d.hours,
      minutes: -d.minutes,
      seconds: -d.seconds
    }
  end

  @doc """
  Add two durations component-wise.
  """
  @spec add(t(), t()) :: t()
  def add(%__MODULE__{} = a, %__MODULE__{} = b) do
    %__MODULE__{
      years: a.years + b.years,
      months: a.months + b.months,
      days: a.days + b.days,
      hours: a.hours + b.hours,
      minutes: a.minutes + b.minutes,
      seconds: a.seconds + b.seconds
    }
  end

  @doc """
  Convert the duration to a total number of seconds (day-time part only).
  Year/month components are ignored as they are calendar-dependent.
  """
  @spec to_seconds(t()) :: number()
  def to_seconds(%__MODULE__{} = d) do
    d.days * 86_400 + d.hours * 3600 + d.minutes * 60 + d.seconds
  end

  @doc """
  Convert the duration to total months (year-month part only).
  Day/time components are ignored.
  """
  @spec to_months(t()) :: integer()
  def to_months(%__MODULE__{} = d) do
    d.years * 12 + d.months
  end

  @doc """
  Compare two durations. Only comparable if both are the same subtype.
  Returns `:lt`, `:eq`, or `:gt`.
  """
  @spec compare(t(), t()) :: :lt | :eq | :gt | :error
  def compare(%__MODULE__{} = a, %__MODULE__{} = b) do
    cond do
      year_month?(a) and year_month?(b) ->
        compare_values(to_months(a), to_months(b))

      day_time?(a) and day_time?(b) ->
        compare_values(to_seconds(a), to_seconds(b))

      true ->
        :error
    end
  end

  defp compare_values(a, b) when a < b, do: :lt
  defp compare_values(a, b) when a > b, do: :gt
  defp compare_values(_, _), do: :eq
end
