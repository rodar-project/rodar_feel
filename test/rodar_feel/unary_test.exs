defmodule RodarFeel.UnaryTestTest do
  use ExUnit.Case, async: true

  # --- Parsing ---

  describe "unary test parsing" do
    test "wildcard" do
      assert {:ok, {:unary_wildcard}} = RodarFeel.Parser.parse_unary("-")
    end

    test "comparison operators" do
      assert {:ok, {:unary_cmp, :<, {:literal, 100}}} = RodarFeel.Parser.parse_unary("< 100")
      assert {:ok, {:unary_cmp, :>, {:literal, 5}}} = RodarFeel.Parser.parse_unary("> 5")
      assert {:ok, {:unary_cmp, :<=, {:literal, 10}}} = RodarFeel.Parser.parse_unary("<= 10")
      assert {:ok, {:unary_cmp, :>=, {:literal, 0}}} = RodarFeel.Parser.parse_unary(">= 0")
      assert {:ok, {:unary_cmp, :==, {:literal, 42}}} = RodarFeel.Parser.parse_unary("= 42")
      assert {:ok, {:unary_cmp, :!=, {:literal, 0}}} = RodarFeel.Parser.parse_unary("!= 0")
    end

    test "inclusive range" do
      assert {:ok, {:unary_range, {:literal, 1}, {:literal, 5}, true, true}} =
               RodarFeel.Parser.parse_unary("[1..5]")
    end

    test "exclusive range" do
      assert {:ok, {:unary_range, {:literal, 1}, {:literal, 5}, false, false}} =
               RodarFeel.Parser.parse_unary("(1..5)")
    end

    test "half-open ranges" do
      assert {:ok, {:unary_range, {:literal, 1}, {:literal, 5}, true, false}} =
               RodarFeel.Parser.parse_unary("[1..5)")

      assert {:ok, {:unary_range, {:literal, 1}, {:literal, 5}, false, true}} =
               RodarFeel.Parser.parse_unary("(1..5]")
    end

    test "negated test" do
      assert {:ok, {:unary_not, {:unary_cmp, :<, {:literal, 100}}}} =
               RodarFeel.Parser.parse_unary("not(< 100)")
    end

    test "disjunction" do
      {:ok, {:unary_disjunction, tests}} = RodarFeel.Parser.parse_unary("1, 2, 3")
      assert length(tests) == 3
    end

    test "plain value" do
      assert {:ok, {:unary_value, {:literal, 42}}} = RodarFeel.Parser.parse_unary("42")
    end

    test "string value" do
      assert {:ok, {:unary_value, {:literal, "foo"}}} =
               RodarFeel.Parser.parse_unary(~s|"foo"|)
    end
  end

  # --- Wildcard ---

  describe "wildcard evaluation" do
    test "matches any number" do
      assert {:ok, true} = RodarFeel.eval_unary("-", 42)
    end

    test "matches nil" do
      assert {:ok, true} = RodarFeel.eval_unary("-", nil)
    end

    test "matches string" do
      assert {:ok, true} = RodarFeel.eval_unary("-", "anything")
    end
  end

  # --- Comparison tests ---

  describe "comparison test evaluation" do
    test "less than" do
      assert {:ok, true} = RodarFeel.eval_unary("< 100", 50)
      assert {:ok, false} = RodarFeel.eval_unary("< 100", 100)
      assert {:ok, false} = RodarFeel.eval_unary("< 100", 200)
    end

    test "greater than" do
      assert {:ok, true} = RodarFeel.eval_unary("> 0", 5)
      assert {:ok, false} = RodarFeel.eval_unary("> 0", 0)
    end

    test "less than or equal" do
      assert {:ok, true} = RodarFeel.eval_unary("<= 100", 100)
      assert {:ok, false} = RodarFeel.eval_unary("<= 100", 101)
    end

    test "greater than or equal" do
      assert {:ok, true} = RodarFeel.eval_unary(">= 0", 0)
      assert {:ok, false} = RodarFeel.eval_unary(">= 0", -1)
    end

    test "equal" do
      assert {:ok, true} = RodarFeel.eval_unary("= 42", 42)
      assert {:ok, false} = RodarFeel.eval_unary("= 42", 43)
    end

    test "not equal" do
      assert {:ok, true} = RodarFeel.eval_unary("!= 0", 1)
      assert {:ok, false} = RodarFeel.eval_unary("!= 0", 0)
    end

    test "comparison with expression" do
      assert {:ok, true} = RodarFeel.eval_unary("> x", 10, %{"x" => 5})
      assert {:ok, false} = RodarFeel.eval_unary("> x", 3, %{"x" => 5})
    end

    test "comparison with string" do
      assert {:ok, true} = RodarFeel.eval_unary(~s|= "high"|, "high")
      assert {:ok, false} = RodarFeel.eval_unary(~s|= "high"|, "low")
    end
  end

  # --- Range tests ---

  describe "range test evaluation" do
    test "inclusive range includes endpoints" do
      assert {:ok, true} = RodarFeel.eval_unary("[1..5]", 1)
      assert {:ok, true} = RodarFeel.eval_unary("[1..5]", 3)
      assert {:ok, true} = RodarFeel.eval_unary("[1..5]", 5)
      assert {:ok, false} = RodarFeel.eval_unary("[1..5]", 0)
      assert {:ok, false} = RodarFeel.eval_unary("[1..5]", 6)
    end

    test "exclusive range excludes endpoints" do
      assert {:ok, false} = RodarFeel.eval_unary("(1..5)", 1)
      assert {:ok, true} = RodarFeel.eval_unary("(1..5)", 3)
      assert {:ok, false} = RodarFeel.eval_unary("(1..5)", 5)
    end

    test "half-open range [a..b)" do
      assert {:ok, true} = RodarFeel.eval_unary("[1..5)", 1)
      assert {:ok, true} = RodarFeel.eval_unary("[1..5)", 4)
      assert {:ok, false} = RodarFeel.eval_unary("[1..5)", 5)
    end

    test "half-open range (a..b]" do
      assert {:ok, false} = RodarFeel.eval_unary("(1..5]", 1)
      assert {:ok, true} = RodarFeel.eval_unary("(1..5]", 5)
    end

    test "range with expressions" do
      assert {:ok, true} = RodarFeel.eval_unary("[lo..hi]", 5, %{"lo" => 1, "hi" => 10})
      assert {:ok, false} = RodarFeel.eval_unary("[lo..hi]", 15, %{"lo" => 1, "hi" => 10})
    end
  end

  # --- Negated tests ---

  describe "negated test evaluation" do
    test "not comparison" do
      assert {:ok, true} = RodarFeel.eval_unary("not(< 100)", 200)
      assert {:ok, false} = RodarFeel.eval_unary("not(< 100)", 50)
    end

    test "not range" do
      assert {:ok, true} = RodarFeel.eval_unary("not([1..5])", 10)
      assert {:ok, false} = RodarFeel.eval_unary("not([1..5])", 3)
    end

    test "not value" do
      assert {:ok, true} = RodarFeel.eval_unary("not(42)", 99)
      assert {:ok, false} = RodarFeel.eval_unary("not(42)", 42)
    end
  end

  # --- Disjunction ---

  describe "disjunction evaluation" do
    test "matches any value in list" do
      assert {:ok, true} = RodarFeel.eval_unary("1, 2, 3", 2)
      assert {:ok, false} = RodarFeel.eval_unary("1, 2, 3", 4)
    end

    test "short-circuits on first match" do
      assert {:ok, true} = RodarFeel.eval_unary("1, 2, 3", 1)
    end

    test "string disjunction" do
      assert {:ok, true} = RodarFeel.eval_unary(~s|"high", "low"|, "high")
      assert {:ok, true} = RodarFeel.eval_unary(~s|"high", "low"|, "low")
      assert {:ok, false} = RodarFeel.eval_unary(~s|"high", "low"|, "medium")
    end

    test "mixed tests in disjunction" do
      assert {:ok, true} = RodarFeel.eval_unary("< 0, > 100", -5)
      assert {:ok, true} = RodarFeel.eval_unary("< 0, > 100", 200)
      assert {:ok, false} = RodarFeel.eval_unary("< 0, > 100", 50)
    end

    test "ranges in disjunction" do
      assert {:ok, true} = RodarFeel.eval_unary("[1..5], [10..15]", 3)
      assert {:ok, true} = RodarFeel.eval_unary("[1..5], [10..15]", 12)
      assert {:ok, false} = RodarFeel.eval_unary("[1..5], [10..15]", 7)
    end
  end

  # --- Plain value equality ---

  describe "plain value equality" do
    test "number" do
      assert {:ok, true} = RodarFeel.eval_unary("42", 42)
      assert {:ok, false} = RodarFeel.eval_unary("42", 99)
    end

    test "string" do
      assert {:ok, true} = RodarFeel.eval_unary(~s|"approved"|, "approved")
      assert {:ok, false} = RodarFeel.eval_unary(~s|"approved"|, "rejected")
    end

    test "boolean" do
      assert {:ok, true} = RodarFeel.eval_unary("true", true)
      assert {:ok, false} = RodarFeel.eval_unary("true", false)
    end

    test "null" do
      assert {:ok, true} = RodarFeel.eval_unary("null", nil)
      assert {:ok, false} = RodarFeel.eval_unary("null", 0)
    end
  end

  # --- Bindings support ---

  describe "bindings in unary tests" do
    test "variable in comparison" do
      assert {:ok, true} = RodarFeel.eval_unary("> threshold", 150, %{"threshold" => 100})
    end

    test "variable in value" do
      assert {:ok, true} = RodarFeel.eval_unary("expected", "ok", %{"expected" => "ok"})
    end

    test "expression in range endpoint" do
      assert {:ok, true} = RodarFeel.eval_unary("[min..max]", 5, %{"min" => 1, "max" => 10})
    end
  end

  # --- Temporal values in unary tests ---

  describe "temporal unary tests" do
    test "date comparison" do
      assert {:ok, true} = RodarFeel.eval_unary(~s|> @"2024-01-01"|, ~D[2024-06-15])
      assert {:ok, false} = RodarFeel.eval_unary(~s|> @"2024-01-01"|, ~D[2023-06-15])
    end

    test "date range" do
      assert {:ok, true} =
               RodarFeel.eval_unary(~s|[@"2024-01-01"..@"2024-12-31"]|, ~D[2024-06-15])

      assert {:ok, false} =
               RodarFeel.eval_unary(~s|[@"2024-01-01"..@"2024-12-31"]|, ~D[2025-01-01])
    end
  end
end
