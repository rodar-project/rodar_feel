defmodule RodarFeel.Phase5Test do
  use ExUnit.Case, async: true

  # --- instance of ---

  describe "instance of" do
    test "number" do
      assert {:ok, true} = RodarFeel.eval("42 instance of number", %{})
      assert {:ok, true} = RodarFeel.eval("3.14 instance of number", %{})
      assert {:ok, false} = RodarFeel.eval(~s|"hi" instance of number|, %{})
    end

    test "string" do
      assert {:ok, true} = RodarFeel.eval(~s|"hello" instance of string|, %{})
      assert {:ok, false} = RodarFeel.eval("42 instance of string", %{})
    end

    test "boolean" do
      assert {:ok, true} = RodarFeel.eval("true instance of boolean", %{})
      assert {:ok, true} = RodarFeel.eval("false instance of boolean", %{})
      assert {:ok, false} = RodarFeel.eval("1 instance of boolean", %{})
    end

    test "null" do
      assert {:ok, true} = RodarFeel.eval("null instance of null", %{})
      assert {:ok, false} = RodarFeel.eval("0 instance of null", %{})
    end

    test "null is not other types" do
      assert {:ok, false} = RodarFeel.eval("null instance of number", %{})
      assert {:ok, false} = RodarFeel.eval("null instance of string", %{})
    end

    test "any matches everything" do
      assert {:ok, true} = RodarFeel.eval("42 instance of any", %{})
      assert {:ok, true} = RodarFeel.eval(~s|"hi" instance of any|, %{})
      assert {:ok, true} = RodarFeel.eval("null instance of any", %{})
    end

    test "date" do
      assert {:ok, true} = RodarFeel.eval(~s|@"2024-03-20" instance of date|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|@"10:30:00" instance of date|, %{})
    end

    test "time" do
      assert {:ok, true} = RodarFeel.eval(~s|@"10:30:00" instance of time|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|@"2024-03-20" instance of time|, %{})
    end

    test "date and time" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"2024-03-20T10:30:00" instance of date and time|, %{})

      assert {:ok, false} = RodarFeel.eval(~s|@"2024-03-20" instance of date and time|, %{})
    end

    test "duration" do
      assert {:ok, true} = RodarFeel.eval(~s|@"P1Y2M" instance of duration|, %{})
      assert {:ok, true} = RodarFeel.eval(~s|@"PT1H" instance of duration|, %{})
    end

    test "years and months duration" do
      assert {:ok, true} =
               RodarFeel.eval(~s|@"P1Y2M" instance of years and months duration|, %{})

      assert {:ok, false} =
               RodarFeel.eval(~s|@"PT1H" instance of years and months duration|, %{})
    end

    test "days and time duration" do
      assert {:ok, true} = RodarFeel.eval(~s|@"PT1H" instance of days and time duration|, %{})

      assert {:ok, false} =
               RodarFeel.eval(~s|@"P1Y2M" instance of days and time duration|, %{})
    end

    test "list" do
      assert {:ok, true} = RodarFeel.eval("[1, 2, 3] instance of list", %{})
      assert {:ok, false} = RodarFeel.eval("42 instance of list", %{})
    end

    test "context" do
      assert {:ok, true} = RodarFeel.eval("{a: 1} instance of context", %{})
      assert {:ok, false} = RodarFeel.eval("[1] instance of context", %{})
    end

    test "function" do
      bindings = %{"f" => {:feel_function, ["x"], {:path, ["x"]}, %{}}}
      assert {:ok, true} = RodarFeel.eval("f instance of function", bindings)
      assert {:ok, false} = RodarFeel.eval("42 instance of function", %{})
    end

    test "with variable" do
      assert {:ok, true} = RodarFeel.eval("x instance of number", %{"x" => 42})
      assert {:ok, false} = RodarFeel.eval("x instance of number", %{"x" => "hi"})
    end
  end

  # --- number() ---

  describe "number() function" do
    test "parse integer string" do
      assert {:ok, 42} = RodarFeel.eval(~s|number("42")|, %{})
    end

    test "parse float string" do
      assert {:ok, 3.14} = RodarFeel.eval(~s|number("3.14")|, %{})
    end

    test "parse negative" do
      assert {:ok, -5} = RodarFeel.eval(~s|number("-5")|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval("number(null)", %{})
    end

    test "invalid string" do
      assert {:error, _} = RodarFeel.eval(~s|number("abc")|, %{})
    end

    test "locale-aware parsing" do
      assert {:ok, 1000.5} = RodarFeel.eval(~s|number("1,000.50", ",", ".")|, %{})
    end

    test "european locale" do
      assert {:ok, 1000.5} = RodarFeel.eval(~s|number("1.000,50", ".", ",")|, %{})
    end

    test "space grouping" do
      assert {:ok, 1000} = RodarFeel.eval(~s|number("1 000", " ", ".")|, %{})
    end
  end

  # --- Statistical functions ---

  describe "median()" do
    test "odd count" do
      assert {:ok, 3} = RodarFeel.eval("median([1, 2, 3, 4, 5])", %{})
    end

    test "even count" do
      assert {:ok, 2.5} = RodarFeel.eval("median([1, 2, 3, 4])", %{})
    end

    test "single element" do
      assert {:ok, 7} = RodarFeel.eval("median([7])", %{})
    end

    test "unsorted input" do
      assert {:ok, 3} = RodarFeel.eval("median([5, 1, 3])", %{})
    end

    test "empty list" do
      assert {:ok, nil} = RodarFeel.eval("median([])", %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval("median(null)", %{})
      assert {:ok, nil} = RodarFeel.eval("median([1, null, 3])", %{})
    end
  end

  describe "stddev()" do
    test "sample standard deviation" do
      {:ok, result} = RodarFeel.eval("stddev([2, 4, 4, 4, 5, 5, 7, 9])", %{})
      assert_in_delta result, 2.138, 0.001
    end

    test "too few elements" do
      assert {:ok, nil} = RodarFeel.eval("stddev([5])", %{})
      assert {:ok, nil} = RodarFeel.eval("stddev([])", %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval("stddev(null)", %{})
      assert {:ok, nil} = RodarFeel.eval("stddev([1, null, 3])", %{})
    end
  end

  describe "mode()" do
    test "single mode" do
      assert {:ok, [2]} = RodarFeel.eval("mode([1, 2, 2, 3])", %{})
    end

    test "multiple modes" do
      assert {:ok, [2, 3]} = RodarFeel.eval("mode([1, 2, 2, 3, 3])", %{})
    end

    test "all same frequency" do
      assert {:ok, [1, 2, 3]} = RodarFeel.eval("mode([1, 2, 3])", %{})
    end

    test "empty list" do
      assert {:ok, []} = RodarFeel.eval("mode([])", %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval("mode(null)", %{})
      assert {:ok, nil} = RodarFeel.eval("mode([1, null, 3])", %{})
    end
  end

  # --- random() ---

  describe "random()" do
    test "returns number between 0 and 1" do
      {:ok, result} = RodarFeel.eval("random()", %{})
      assert is_float(result)
      assert result >= 0.0 and result < 1.0
    end
  end

  # --- matches() ---

  describe "matches()" do
    test "simple match" do
      assert {:ok, true} = RodarFeel.eval(~s|matches("foobar", "foo")|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|matches("foobar", "baz")|, %{})
    end

    test "regex match" do
      assert {:ok, true} = RodarFeel.eval(~s|matches("hello", "^h.*o$")|, %{})
      assert {:ok, false} = RodarFeel.eval(~s|matches("hello", "^x")|, %{})
    end

    test "digit pattern" do
      assert {:ok, true} = RodarFeel.eval(~s|matches("abc123", "\\\\d+")|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval(~s|matches(null, "foo")|, %{})
      assert {:ok, nil} = RodarFeel.eval(~s|matches("foo", null)|, %{})
    end

    test "invalid regex" do
      assert {:error, _} = RodarFeel.eval(~s|matches("foo", "[")|, %{})
    end
  end

  # --- string join ---

  describe "string join()" do
    test "with delimiter" do
      assert {:ok, "a-b-c"} = RodarFeel.eval(~s|string join(["a", "b", "c"], "-")|, %{})
    end

    test "without delimiter" do
      assert {:ok, "abc"} = RodarFeel.eval(~s|string join(["a", "b", "c"])|, %{})
    end

    test "with space delimiter" do
      assert {:ok, "hello world"} =
               RodarFeel.eval(~s|string join(["hello", "world"], " ")|, %{})
    end

    test "skips null elements" do
      assert {:ok, "ac"} = RodarFeel.eval(~s|string join(["a", null, "c"])|, %{})
    end

    test "empty list" do
      assert {:ok, ""} = RodarFeel.eval(~s|string join([])|, %{})
    end

    test "null propagation" do
      assert {:ok, nil} = RodarFeel.eval("string join(null)", %{})
      assert {:ok, nil} = RodarFeel.eval(~s|string join(null, ",")|, %{})
    end
  end

  # --- User-defined functions / lambdas ---

  describe "lambda expressions" do
    test "parse lambda" do
      {:ok, ast} = RodarFeel.Parser.parse("function(x) x + 1")
      assert {:lambda, ["x"], {:binop, :+, {:path, ["x"]}, {:literal, 1}}} = ast
    end

    test "parse multi-param lambda" do
      {:ok, ast} = RodarFeel.Parser.parse("function(x, y) x + y")
      assert {:lambda, ["x", "y"], _body} = ast
    end

    test "lambda returns function value" do
      {:ok, result} = RodarFeel.eval("function(x) x + 1", %{})
      assert {:feel_function, ["x"], _, _} = result
    end

    test "invoke lambda via variable" do
      {:ok, f} = RodarFeel.eval("function(x, y) x + y", %{})
      assert {:ok, 7} = RodarFeel.eval("add(3, 4)", %{"add" => f})
    end

    test "lambda captures closure" do
      {:ok, f} = RodarFeel.eval("function(x) x + base", %{"base" => 10})
      assert {:ok, 15} = RodarFeel.eval("f(5)", %{"f" => f})
    end

    test "lambda in context" do
      assert {:ok, %{"sq" => _, "result" => 25}} =
               RodarFeel.eval("{sq: function(x) x * x, result: sq(5)}", %{})
    end

    test "lambda wrong arity" do
      {:ok, f} = RodarFeel.eval("function(x, y) x + y", %{})
      assert {:error, _} = RodarFeel.eval("f(1)", %{"f" => f})
    end

    test "zero-param lambda" do
      {:ok, f} = RodarFeel.eval("function() 42", %{})
      assert {:ok, 42} = RodarFeel.eval("f()", %{"f" => f})
    end

    test "higher-order: lambda passed as argument" do
      {:ok, double} = RodarFeel.eval("function(x) x * 2", %{})

      assert {:ok, result} =
               RodarFeel.eval(
                 "for x in [1, 2, 3] return f(x)",
                 %{"f" => double}
               )

      assert result == [2, 4, 6]
    end
  end
end
