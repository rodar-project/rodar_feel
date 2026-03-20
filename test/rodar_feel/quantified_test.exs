defmodule RodarFeel.QuantifiedTest do
  use ExUnit.Case, async: true

  describe "some expression" do
    test "some true when any element satisfies" do
      assert {:ok, true} = RodarFeel.eval("some x in [1, 2, 3] satisfies x > 2", %{})
    end

    test "some false when no element satisfies" do
      assert {:ok, false} = RodarFeel.eval("some x in [1, 2, 3] satisfies x > 5", %{})
    end

    test "some with variable from bindings" do
      assert {:ok, true} =
               RodarFeel.eval("some x in items satisfies x > 2", %{"items" => [1, 2, 3]})
    end

    test "some with empty list" do
      assert {:ok, false} = RodarFeel.eval("some x in [] satisfies x > 0", %{})
    end

    test "three-valued: some with nil elements" do
      assert {:ok, true} =
               RodarFeel.eval("some x in items satisfies x > 2", %{"items" => [nil, 3]})
    end

    test "three-valued: nil comparison with nil returns false" do
      # nil > 5 returns false in FEEL, so this is all false
      assert {:ok, false} =
               RodarFeel.eval("some x in items satisfies x > 5", %{"items" => [nil, 3]})
    end

    test "three-valued: nil when condition produces nil via and" do
      # true and nil => nil, so condition produces nil for the second element
      assert {:ok, nil} =
               RodarFeel.eval("some x in items satisfies true and x", %{
                 "items" => [false, nil]
               })
    end
  end

  describe "every expression" do
    test "every true when all elements satisfy" do
      assert {:ok, true} = RodarFeel.eval("every x in [1, 2, 3] satisfies x > 0", %{})
    end

    test "every false when any element does not satisfy" do
      assert {:ok, false} = RodarFeel.eval("every x in [1, 2, 3] satisfies x > 1", %{})
    end

    test "every with variable from bindings" do
      assert {:ok, true} =
               RodarFeel.eval("every x in items satisfies x > 0", %{"items" => [1, 2, 3]})
    end

    test "every with empty list" do
      assert {:ok, true} = RodarFeel.eval("every x in [] satisfies x > 0", %{})
    end

    test "three-valued: every with nil elements" do
      assert {:ok, false} =
               RodarFeel.eval("every x in items satisfies x > 2", %{"items" => [nil, 1]})
    end

    test "three-valued: nil when no false but some nil via and" do
      # true and nil => nil, condition produces nil for second element
      assert {:ok, nil} =
               RodarFeel.eval("every x in items satisfies true and x", %{"items" => [true, nil]})
    end
  end

  describe "some parser AST" do
    test "produces some AST node" do
      {:ok, ast} = RodarFeel.Parser.parse("some x in [1, 2] satisfies x > 1")

      assert {:some, [{"x", {:list, [{:literal, 1}, {:literal, 2}]}}],
              {:binop, :>, {:path, ["x"]}, {:literal, 1}}} = ast
    end
  end

  describe "every parser AST" do
    test "produces every AST node" do
      {:ok, ast} = RodarFeel.Parser.parse("every x in items satisfies x > 0")

      assert {:every, [{"x", {:path, ["items"]}}], {:binop, :>, {:path, ["x"]}, {:literal, 0}}} =
               ast
    end
  end
end
