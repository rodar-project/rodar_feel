defmodule RodarFeel.TimezoneTest do
  use ExUnit.Case, async: true

  alias RodarFeel.Duration

  # --- Timezone-aware literal parsing ---

  describe "timezone-aware temporal literals" do
    test "UTC with Z suffix" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z"|, %{})
      assert %DateTime{} = result
      assert result.time_zone == "Etc/UTC"
    end

    test "positive UTC offset" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00+05:00"|, %{})
      assert %DateTime{} = result
      # Elixir normalizes to UTC
      assert result.hour == 5
      assert result.minute == 30
    end

    test "negative UTC offset" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00-04:00"|, %{})
      assert %DateTime{} = result
      assert result.hour == 14
      assert result.minute == 30
    end

    test "naive datetime still works (no timezone)" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00"|, %{})
      assert %NaiveDateTime{} = result
    end
  end

  # --- Construction with timezone ---

  describe "date and time() with timezone" do
    test "from naive datetime and timezone string" do
      {:ok, result} =
        RodarFeel.eval(
          ~s|date and time(@"2024-03-20T10:30:00", "America/New_York")|,
          %{}
        )

      assert %DateTime{} = result
      assert result.time_zone == "America/New_York"
      assert result.hour == 10
    end

    test "from date, time, and timezone string" do
      {:ok, result} =
        RodarFeel.eval(
          ~s|date and time(date("2024-06-15"), time("14:00:00"), "Europe/London")|,
          %{}
        )

      assert %DateTime{} = result
      assert result.time_zone == "Europe/London"
      assert result.hour == 14
    end

    test "from ISO string with Z" do
      {:ok, result} = RodarFeel.eval(~s|date and time("2024-03-20T10:30:00Z")|, %{})
      # Parsed as NaiveDateTime since the function uses NaiveDateTime.from_iso8601
      # (Z is stripped by NaiveDateTime parser)
      assert %NaiveDateTime{} = result
    end

    test "null propagation with timezone" do
      assert {:ok, nil} = RodarFeel.eval(~s|date and time(null, "UTC")|, %{})
      assert {:ok, nil} = RodarFeel.eval(~s|date and time(@"2024-03-20T10:30:00", null)|, %{})
    end
  end

  # --- Property access on DateTime ---

  describe "DateTime property access" do
    test "date/time properties" do
      assert {:ok, 2024} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".year|, %{})
      assert {:ok, 3} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".month|, %{})
      assert {:ok, 20} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".day|, %{})
      assert {:ok, 10} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".hour|, %{})
      assert {:ok, 30} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".minute|, %{})
      assert {:ok, 0} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".second|, %{})
    end

    test "timezone property" do
      assert {:ok, "Etc/UTC"} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".timezone|, %{})
    end

    test "offset property" do
      assert {:ok, 0} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z".offset|, %{})
    end

    test "properties via variable" do
      dt = DateTime.from_naive!(~N[2024-06-15 14:00:00], "America/New_York", Tz.TimeZoneDatabase)
      bindings = %{"dt" => dt}

      assert {:ok, "America/New_York"} = RodarFeel.eval("dt.timezone", bindings)
      assert {:ok, 2024} = RodarFeel.eval("dt.year", bindings)
    end
  end

  # --- DateTime arithmetic ---

  describe "DateTime arithmetic" do
    test "datetime + day duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" + @"P5D"|, %{})
      assert %DateTime{} = result
      assert result.day == 25
    end

    test "datetime + hour duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" + @"PT2H"|, %{})
      assert result.hour == 12
    end

    test "datetime - duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" - @"P5D"|, %{})
      assert result.day == 15
    end

    test "datetime - datetime gives duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" - @"2024-03-15T10:30:00Z"|, %{})
      assert %Duration{days: 5} = result
    end

    test "duration + datetime (commutative)" do
      {:ok, result} = RodarFeel.eval(~s|@"P5D" + @"2024-03-20T10:30:00Z"|, %{})
      assert %DateTime{} = result
      assert result.day == 25
    end

    test "datetime + month duration preserves timezone" do
      dt = DateTime.from_naive!(~N[2024-01-15 12:00:00], "America/New_York", Tz.TimeZoneDatabase)

      {:ok, result} = RodarFeel.eval(~s|dt + @"P3M"|, %{"dt" => dt})
      assert %DateTime{} = result
      assert result.month == 4
      assert result.time_zone == "America/New_York"
    end
  end

  # --- DateTime comparison ---

  describe "DateTime comparison" do
    test "same timezone" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" > @"2024-03-15T10:30:00Z"|, %{})

      assert {:ok, false} =
               RodarFeel.eval(~s|@"2024-03-15T10:30:00Z" > @"2024-03-20T10:30:00Z"|, %{})
    end

    test "equality" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" = @"2024-03-20T10:30:00Z"|, %{})
    end

    test "cross-offset comparison (normalized to UTC)" do
      # 10:30 UTC == 05:30 -05:00
      assert {:ok, true} =
               RodarFeel.eval(
                 ~s|@"2024-03-20T10:30:00Z" = @"2024-03-20T05:30:00-05:00"|,
                 %{}
               )
    end
  end

  # --- now() returns DateTime ---

  describe "now() with timezone" do
    test "returns a UTC DateTime" do
      {:ok, result} = RodarFeel.eval("now()", %{})
      assert %DateTime{} = result
      assert result.time_zone == "Etc/UTC"
    end

    test "now() timezone via variable" do
      {:ok, dt} = RodarFeel.eval("now()", %{})
      assert {:ok, "Etc/UTC"} = RodarFeel.eval("dt.timezone", %{"dt" => dt})
    end
  end

  # --- string() for DateTime ---

  describe "string() with DateTime" do
    test "UTC DateTime" do
      assert {:ok, "2024-03-20T10:30:00Z"} =
               RodarFeel.eval(~s|string(@"2024-03-20T10:30:00Z")|, %{})
    end
  end

  # --- instance of with DateTime ---

  describe "instance of with DateTime" do
    test "DateTime is date and time" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00Z" instance of date and time|, %{})
    end
  end
end
