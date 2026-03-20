defmodule RodarFeel.CommentsTest do
  use ExUnit.Case, async: true

  describe "single-line comments" do
    test "ignores // comment at end of expression" do
      assert {:ok, 3} = RodarFeel.eval("1 + 2 // this is a comment", %{})
    end

    test "ignores // comment before newline" do
      assert {:ok, 3} = RodarFeel.eval("1 + // add\n2", %{})
    end

    test "expression with only a comment after value" do
      assert {:ok, 42} = RodarFeel.eval("42 // the answer", %{})
    end
  end

  describe "multi-line comments" do
    test "ignores /* */ comment in expression" do
      assert {:ok, 3} = RodarFeel.eval("1 /* plus */ + 2", %{})
    end

    test "ignores multi-line /* */ comment" do
      expr = """
      1 + /* this is
      a multi-line
      comment */ 2
      """

      assert {:ok, 3} = RodarFeel.eval(expr, %{})
    end

    test "expression with inline comment" do
      assert {:ok, true} = RodarFeel.eval("/* check */ true", %{})
    end
  end

  describe "mixed comments" do
    test "single-line and multi-line comments together" do
      expr = "1 /* a */ + // b\n2"
      assert {:ok, 3} = RodarFeel.eval(expr, %{})
    end
  end
end
