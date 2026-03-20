defmodule RodarFeel.TemporalTest do
  use ExUnit.Case, async: true

  alias RodarFeel.Duration

  # --- Temporal literal parsing ---

  describe "temporal literals" do
    test "date literal" do
      assert {:ok, ~D[2024-03-20]} = RodarFeel.eval(~s|@"2024-03-20"|, %{})
    end

    test "time literal" do
      assert {:ok, ~T[10:30:00]} = RodarFeel.eval(~s|@"10:30:00"|, %{})
    end

    test "naive datetime literal" do
      assert {:ok, ~N[2024-03-20 10:30:00]} = RodarFeel.eval(~s|@"2024-03-20T10:30:00"|, %{})
    end

    test "year-month duration literal" do
      assert {:ok, %Duration{years: 1, months: 2}} = RodarFeel.eval(~s|@"P1Y2M"|, %{})
    end

    test "day-time duration literal" do
      assert {:ok, %Duration{hours: 1, minutes: 30}} = RodarFeel.eval(~s|@"PT1H30M"|, %{})
    end

    test "full duration literal" do
      assert {:ok, %Duration{years: 1, months: 2, days: 3, hours: 4, minutes: 5, seconds: 6}} =
               RodarFeel.eval(~s|@"P1Y2M3DT4H5M6S"|, %{})
    end

    test "invalid temporal literal" do
      assert {:error, _} = RodarFeel.eval(~s|@"not-a-date"|, %{})
    end
  end

  # --- Construction functions ---

  describe "date() function" do
    test "from ISO string" do
      assert {:ok, ~D[2024-03-20]} = RodarFeel.eval(~s|date("2024-03-20")|, %{})
    end

    test "from year, month, day" do
      assert {:ok, ~D[2024-03-20]} = RodarFeel.eval(~s|date(2024, 3, 20)|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval(~s|date(null)|, %{})
    end

    test "invalid string" do
      assert {:error, _} = RodarFeel.eval(~s|date("not-a-date")|, %{})
    end
  end

  describe "time() function" do
    test "from ISO string" do
      assert {:ok, ~T[10:30:00]} = RodarFeel.eval(~s|time("10:30:00")|, %{})
    end

    test "from hour, minute, second" do
      assert {:ok, ~T[10:30:00]} = RodarFeel.eval(~s|time(10, 30, 0)|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval(~s|time(null)|, %{})
    end
  end

  describe "date and time() function" do
    test "from ISO string" do
      assert {:ok, ~N[2024-03-20 10:30:00]} =
               RodarFeel.eval(~s|date and time("2024-03-20T10:30:00")|, %{})
    end

    test "from date and time values" do
      assert {:ok, ~N[2024-03-20 10:30:00]} =
               RodarFeel.eval(
                 ~s|date and time(date("2024-03-20"), time("10:30:00"))|,
                 %{}
               )
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval(~s|date and time(null)|, %{})
    end
  end

  describe "duration() function" do
    test "year-month duration" do
      assert {:ok, %Duration{years: 1, months: 6}} = RodarFeel.eval(~s|duration("P1Y6M")|, %{})
    end

    test "day-time duration" do
      assert {:ok, %Duration{days: 5, hours: 3}} = RodarFeel.eval(~s|duration("P5DT3H")|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval(~s|duration(null)|, %{})
    end
  end

  describe "now() and today()" do
    test "now returns a NaiveDateTime" do
      {:ok, result} = RodarFeel.eval(~s|now()|, %{})
      assert %NaiveDateTime{} = result
    end

    test "today returns a Date" do
      {:ok, result} = RodarFeel.eval(~s|today()|, %{})
      assert %Date{} = result
    end
  end

  # --- Property access ---

  describe "temporal property access" do
    test "date properties via literal" do
      assert {:ok, 2024} = RodarFeel.eval(~s|@"2024-03-20".year|, %{})
      assert {:ok, 3} = RodarFeel.eval(~s|@"2024-03-20".month|, %{})
      assert {:ok, 20} = RodarFeel.eval(~s|@"2024-03-20".day|, %{})
    end

    test "time properties via literal" do
      assert {:ok, 10} = RodarFeel.eval(~s|@"10:30:45".hour|, %{})
      assert {:ok, 30} = RodarFeel.eval(~s|@"10:30:45".minute|, %{})
      assert {:ok, 45} = RodarFeel.eval(~s|@"10:30:45".second|, %{})
    end

    test "datetime properties via literal" do
      assert {:ok, 2024} = RodarFeel.eval(~s|@"2024-03-20T10:30:45".year|, %{})
      assert {:ok, 10} = RodarFeel.eval(~s|@"2024-03-20T10:30:45".hour|, %{})
    end

    test "date properties via variable" do
      bindings = %{"d" => ~D[2024-03-20]}
      assert {:ok, 2024} = RodarFeel.eval("d.year", bindings)
      assert {:ok, 3} = RodarFeel.eval("d.month", bindings)
      assert {:ok, 20} = RodarFeel.eval("d.day", bindings)
    end

    test "time properties via variable" do
      bindings = %{"t" => ~T[10:30:45]}
      assert {:ok, 10} = RodarFeel.eval("t.hour", bindings)
      assert {:ok, 30} = RodarFeel.eval("t.minute", bindings)
      assert {:ok, 45} = RodarFeel.eval("t.second", bindings)
    end

    test "duration properties via variable" do
      bindings = %{"dur" => %Duration{years: 1, months: 2, days: 3}}
      assert {:ok, 1} = RodarFeel.eval("dur.years", bindings)
      assert {:ok, 2} = RodarFeel.eval("dur.months", bindings)
      assert {:ok, 3} = RodarFeel.eval("dur.days", bindings)
    end

    test "date property used in expression" do
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20".year > 2020|, %{})
    end
  end

  # --- Temporal arithmetic ---

  describe "date arithmetic" do
    test "date + day duration" do
      assert {:ok, ~D[2024-03-30]} = RodarFeel.eval(~s|@"2024-03-20" + @"P10D"|, %{})
    end

    test "date - day duration" do
      assert {:ok, ~D[2024-03-10]} = RodarFeel.eval(~s|@"2024-03-20" - @"P10D"|, %{})
    end

    test "date + month duration" do
      assert {:ok, ~D[2024-06-20]} = RodarFeel.eval(~s|@"2024-03-20" + @"P3M"|, %{})
    end

    test "date + year duration" do
      assert {:ok, ~D[2025-03-20]} = RodarFeel.eval(~s|@"2024-03-20" + @"P1Y"|, %{})
    end

    test "date + month clamps day" do
      # Jan 31 + 1 month = Feb 29 (2024 is leap year)
      assert {:ok, ~D[2024-02-29]} = RodarFeel.eval(~s|@"2024-01-31" + @"P1M"|, %{})
    end

    test "date - date gives duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20" - @"2024-03-10"|, %{})
      assert %Duration{days: 10} = result
    end

    test "date - date negative" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-10" - @"2024-03-20"|, %{})
      assert %Duration{days: -10} = result
    end

    test "duration + date (commutative)" do
      assert {:ok, ~D[2024-03-30]} = RodarFeel.eval(~s|@"P10D" + @"2024-03-20"|, %{})
    end
  end

  describe "time arithmetic" do
    test "time + duration" do
      assert {:ok, ~T[11:30:00]} = RodarFeel.eval(~s|@"10:30:00" + @"PT1H"|, %{})
    end

    test "time - duration" do
      assert {:ok, ~T[09:30:00]} = RodarFeel.eval(~s|@"10:30:00" - @"PT1H"|, %{})
    end

    test "time + duration wraps around midnight" do
      assert {:ok, ~T[01:00:00]} = RodarFeel.eval(~s|@"23:00:00" + @"PT2H"|, %{})
    end

    test "time - time gives duration" do
      {:ok, result} = RodarFeel.eval(~s|@"10:30:00" - @"08:00:00"|, %{})
      assert %Duration{hours: 2, minutes: 30} = result
    end
  end

  describe "datetime arithmetic" do
    test "datetime + duration" do
      assert {:ok, ~N[2024-03-25 10:30:00]} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00" + @"P5D"|, %{})
    end

    test "datetime + time duration" do
      assert {:ok, ~N[2024-03-20 12:30:00]} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00" + @"PT2H"|, %{})
    end

    test "datetime - datetime gives duration" do
      {:ok, result} = RodarFeel.eval(~s|@"2024-03-20T10:00:00" - @"2024-03-20T08:00:00"|, %{})
      assert %Duration{hours: 2} = result
    end

    test "datetime + month duration" do
      assert {:ok, ~N[2024-06-20 10:30:00]} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00" + @"P3M"|, %{})
    end
  end

  describe "duration arithmetic" do
    test "duration + duration" do
      {:ok, result} = RodarFeel.eval(~s|@"P1Y" + @"P6M"|, %{})
      assert %Duration{years: 1, months: 6} = result
    end

    test "duration - duration" do
      {:ok, result} = RodarFeel.eval(~s|@"P1Y6M" - @"P6M"|, %{})
      assert %Duration{years: 1, months: 0} = result
    end
  end

  # --- Temporal comparison ---

  describe "temporal comparison" do
    test "date comparison" do
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" > @"2024-03-10"|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|@"2024-03-20" < @"2024-03-10"|, %{})
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" >= @"2024-03-20"|, %{})
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" <= @"2024-03-20"|, %{})
    end

    test "date equality" do
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" = @"2024-03-20"|, %{})
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" != @"2024-03-10"|, %{})
    end

    test "time comparison" do
      assert {:ok, true} = RodarFeel.eval(~s|@"10:30:00" > @"08:00:00"|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|@"08:00:00" > @"10:30:00"|, %{})
    end

    test "datetime comparison" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00" > @"2024-03-20T08:00:00"|, %{})
    end

    test "duration comparison (same subtype)" do
      assert {:ok, true} = RodarFeel.eval(~s|@"P2Y" > @"P1Y"|, %{})
      assert {:ok, true} = RodarFeel.eval(~s|@"PT2H" > @"PT1H"|, %{})
    end
  end

  # --- Null propagation ---

  describe "temporal null propagation" do
    test "null + duration" do
      assert {:ok, nil} = RodarFeel.eval(~s|null + @"P1D"|, %{})
    end

    test "date + null" do
      assert {:ok, nil} = RodarFeel.eval(~s|@"2024-03-20" + null|, %{})
    end

    test "null comparison with date" do
      assert {:ok, false} = RodarFeel.eval(~s|null > @"2024-03-20"|, %{})
    end

    test "null date property access" do
      assert {:ok, nil} = RodarFeel.eval("d.year", %{"d" => nil})
    end
  end

  # --- string() for temporal values ---

  describe "string() with temporal values" do
    test "date to string" do
      assert {:ok, "2024-03-20"} = RodarFeel.eval(~s|string(@"2024-03-20")|, %{})
    end

    test "time to string" do
      assert {:ok, "10:30:00"} = RodarFeel.eval(~s|string(@"10:30:00")|, %{})
    end

    test "datetime to string" do
      assert {:ok, "2024-03-20T10:30:00"} =
               RodarFeel.eval(~s|string(@"2024-03-20T10:30:00")|, %{})
    end

    test "duration to string" do
      assert {:ok, "P1Y2M"} = RodarFeel.eval(~s|string(@"P1Y2M")|, %{})
    end

    test "zero duration to string" do
      assert {:ok, "PT0S"} = RodarFeel.eval(~s|string(duration("PT0S"))|, %{})
    end
  end

  # --- Duration struct unit tests ---

  describe "Duration.parse/1" do
    test "parses year-month" do
      assert {:ok, %Duration{years: 1, months: 2}} = Duration.parse("P1Y2M")
    end

    test "parses day-time" do
      assert {:ok, %Duration{days: 3, hours: 4, minutes: 5, seconds: 6}} =
               Duration.parse("P3DT4H5M6S")
    end

    test "parses days only" do
      assert {:ok, %Duration{days: 10}} = Duration.parse("P10D")
    end

    test "parses time only" do
      assert {:ok, %Duration{hours: 1, minutes: 30}} = Duration.parse("PT1H30M")
    end

    test "parses fractional seconds" do
      {:ok, d} = Duration.parse("PT1.5S")
      assert_in_delta d.seconds, 1.5, 0.001
    end

    test "rejects invalid" do
      assert {:error, _} = Duration.parse("not-duration")
    end

    test "bare P parses as zero duration" do
      assert {:ok, %Duration{years: 0, months: 0, days: 0, hours: 0, minutes: 0, seconds: 0}} =
               Duration.parse("P")
    end
  end

  describe "Duration helpers" do
    test "year_month?" do
      assert Duration.year_month?(%Duration{years: 1, months: 2})
      refute Duration.year_month?(%Duration{years: 1, days: 1})
    end

    test "day_time?" do
      assert Duration.day_time?(%Duration{days: 1, hours: 2})
      refute Duration.day_time?(%Duration{years: 1, days: 1})
    end

    test "negate" do
      d = %Duration{years: 1, months: 2, days: 3}
      neg = Duration.negate(d)
      assert neg.years == -1
      assert neg.months == -2
      assert neg.days == -3
    end

    test "compare same subtype" do
      assert :lt = Duration.compare(%Duration{months: 6}, %Duration{years: 1})
      assert :gt = Duration.compare(%Duration{hours: 2}, %Duration{hours: 1})
      assert :eq = Duration.compare(%Duration{days: 1}, %Duration{hours: 24})
    end

    test "compare mixed subtypes returns error" do
      assert :error = Duration.compare(%Duration{years: 1}, %Duration{days: 365})
    end
  end
end
