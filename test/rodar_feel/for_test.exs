defmodule RodarFeel.ForTest do
  use ExUnit.Case, async: true

  describe "for-in-return" do
    test "simple iteration with transformation" do
      assert {:ok, [2, 4, 6]} = RodarFeel.eval("for x in [1, 2, 3] return x * 2", %{})
    end

    test "iteration with variable from bindings" do
      assert {:ok, [2, 3, 4]} =
               RodarFeel.eval("for x in items return x + 1", %{"items" => [1, 2, 3]})
    end

    test "iteration with identity" do
      assert {:ok, [1, 2, 3]} = RodarFeel.eval("for x in [1, 2, 3] return x", %{})
    end

    test "multiple iteration variables (cartesian product)" do
      assert {:ok, [3, 4, 4, 5]} =
               RodarFeel.eval("for x in [1, 2], y in [2, 3] return x + y", %{})
    end

    test "empty list iteration" do
      assert {:ok, []} = RodarFeel.eval("for x in [] return x + 1", %{})
    end

    test "iteration with boolean expression" do
      assert {:ok, [false, false, true]} =
               RodarFeel.eval("for x in [1, 2, 3] return x > 2", %{})
    end

    test "iteration with string values" do
      result = RodarFeel.eval(~S|for x in ["a", "b"] return upper case(x)|, %{})
      assert {:ok, ["A", "B"]} = result
    end
  end

  describe "for parser AST" do
    test "produces for AST node" do
      {:ok, ast} = RodarFeel.Parser.parse("for x in [1, 2] return x + 1")

      assert {:for, [{"x", {:list, [{:literal, 1}, {:literal, 2}]}}],
              {:binop, :+, {:path, ["x"]}, {:literal, 1}}} = ast
    end

    test "multiple iteration variables AST" do
      {:ok, ast} = RodarFeel.Parser.parse("for x in xs, y in ys return x + y")

      assert {:for,
              [
                {"x", {:path, ["xs"]}},
                {"y", {:path, ["ys"]}}
              ], {:binop, :+, {:path, ["x"]}, {:path, ["y"]}}} = ast
    end
  end
end
