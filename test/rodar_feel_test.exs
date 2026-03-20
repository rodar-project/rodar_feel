defmodule RodarFeelTest do
  use ExUnit.Case, async: true

  describe "end-to-end evaluation" do
    test "simple arithmetic" do
      assert {:ok, 7} = RodarFeel.eval("2 * 3 + 1", %{})
    end

    test "string expression" do
      assert {:ok, "Alice"} = RodarFeel.eval("name", %{"name" => "Alice"})
    end

    test "comparison with variable" do
      assert {:ok, true} = RodarFeel.eval("amount > 1000", %{"amount" => 1500})
      assert {:ok, false} = RodarFeel.eval("amount > 1000", %{"amount" => 500})
    end

    test "null literal" do
      assert {:ok, nil} = RodarFeel.eval("null", %{})
    end

    test "boolean literals" do
      assert {:ok, true} = RodarFeel.eval("true", %{})
      assert {:ok, false} = RodarFeel.eval("false", %{})
    end
  end

  describe "gateway-style conditions" do
    test "compound boolean condition" do
      bindings = %{"amount" => 1500, "status" => "approved"}
      assert {:ok, true} = RodarFeel.eval(~S(amount > 1000 and status = "approved"), bindings)
    end

    test "compound condition with false" do
      bindings = %{"amount" => 500, "status" => "approved"}
      assert {:ok, false} = RodarFeel.eval(~S(amount > 1000 and status = "approved"), bindings)
    end

    test "or condition" do
      bindings = %{"priority" => "high", "amount" => 50}
      assert {:ok, true} = RodarFeel.eval(~S(priority = "high" or amount > 100), bindings)
    end
  end

  describe "null handling" do
    test "missing field comparison returns false" do
      assert {:ok, false} = RodarFeel.eval("missing_field > 5", %{})
    end

    test "null arithmetic propagates" do
      assert {:ok, nil} = RodarFeel.eval("missing + 5", %{})
    end

    test "null equality" do
      assert {:ok, true} = RodarFeel.eval("x = null", %{})
      assert {:ok, false} = RodarFeel.eval("x = null", %{"x" => 42})
    end
  end

  describe "function calls" do
    test "string length" do
      assert {:ok, true} = RodarFeel.eval(~S|string length(name) > 0|, %{"name" => "Alice"})
    end

    test "abs function" do
      assert {:ok, 5} = RodarFeel.eval(~S|abs(-5)|, %{})
    end

    test "upper case" do
      assert {:ok, "HELLO"} = RodarFeel.eval(~S|upper case("hello")|, %{})
    end

    test "contains function" do
      assert {:ok, true} = RodarFeel.eval(~S|contains(email, "@")|, %{"email" => "a@b.com"})
    end

    test "is null function" do
      assert {:ok, true} = RodarFeel.eval(~S|is null(x)|, %{})
      assert {:ok, false} = RodarFeel.eval(~S|is null(x)|, %{"x" => 1})
    end

    test "count function" do
      assert {:ok, 3} = RodarFeel.eval(~S|count(items)|, %{"items" => [1, 2, 3]})
    end

    test "sum function" do
      assert {:ok, 6} = RodarFeel.eval(~S|sum(items)|, %{"items" => [1, 2, 3]})
    end
  end

  describe "in operator" do
    test "value in list" do
      assert {:ok, true} =
               RodarFeel.eval(~S(status in ["active", "pending"]), %{"status" => "active"})
    end

    test "value not in list" do
      assert {:ok, false} =
               RodarFeel.eval(~S(status in ["active", "pending"]), %{"status" => "closed"})
    end

    test "value in range" do
      assert {:ok, true} = RodarFeel.eval("age in 18..65", %{"age" => 30})
      assert {:ok, false} = RodarFeel.eval("age in 18..65", %{"age" => 10})
    end
  end

  describe "if-then-else" do
    test "true condition" do
      assert {:ok, "high"} =
               RodarFeel.eval(~S(if amount > 100 then "high" else "low"), %{"amount" => 200})
    end

    test "false condition" do
      assert {:ok, "low"} =
               RodarFeel.eval(~S(if amount > 100 then "high" else "low"), %{"amount" => 50})
    end
  end

  describe "path access" do
    test "nested path" do
      bindings = %{"order" => %{"customer" => %{"name" => "Alice"}}}
      assert {:ok, "Alice"} = RodarFeel.eval("order.customer.name", bindings)
    end

    test "bracket access" do
      bindings = %{"data" => %{"key" => "value"}}
      assert {:ok, "value"} = RodarFeel.eval(~S(data["key"]), bindings)
    end
  end

  describe "string operations" do
    test "string concatenation via +" do
      assert {:ok, "hello world"} = RodarFeel.eval(~S("hello" + " " + "world"), %{})
    end
  end

  describe "list literals" do
    test "list in expression" do
      assert {:ok, [1, 2, 3]} = RodarFeel.eval("[1, 2, 3]", %{})
    end

    test "empty list" do
      assert {:ok, []} = RodarFeel.eval("[]", %{})
    end
  end

  describe "precedence" do
    test "multiplication before addition" do
      assert {:ok, 7} = RodarFeel.eval("1 + 2 * 3", %{})
    end

    test "parentheses override precedence" do
      assert {:ok, 9} = RodarFeel.eval("(1 + 2) * 3", %{})
    end

    test "comparison before boolean" do
      assert {:ok, true} = RodarFeel.eval("1 < 2 and 3 > 2", %{})
    end
  end

  describe "error handling" do
    test "parse error returns error tuple" do
      assert {:error, _} = RodarFeel.eval("1 +", %{})
    end

    test "division by zero returns error" do
      assert {:error, "division by zero"} = RodarFeel.eval("10 / 0", %{})
    end
  end
end
