defmodule RodarFeel.BetweenTest do
  use ExUnit.Case, async: true

  describe "between operator" do
    test "value within range returns true" do
      assert {:ok, true} = RodarFeel.eval("5 between 1 and 10", %{})
    end

    test "value at lower bound returns true" do
      assert {:ok, true} = RodarFeel.eval("1 between 1 and 10", %{})
    end

    test "value at upper bound returns true" do
      assert {:ok, true} = RodarFeel.eval("10 between 1 and 10", %{})
    end

    test "value below range returns false" do
      assert {:ok, false} = RodarFeel.eval("0 between 1 and 10", %{})
    end

    test "value above range returns false" do
      assert {:ok, false} = RodarFeel.eval("11 between 1 and 10", %{})
    end

    test "works with variables" do
      assert {:ok, true} = RodarFeel.eval("x between 10 and 20", %{"x" => 15})
      assert {:ok, false} = RodarFeel.eval("x between 10 and 20", %{"x" => 5})
    end

    test "works with float values" do
      assert {:ok, true} = RodarFeel.eval("3.14 between 3.0 and 4.0", %{})
    end

    test "null propagation - null value" do
      assert {:ok, nil} = RodarFeel.eval("x between 1 and 10", %{})
    end

    test "null propagation - null low bound" do
      assert {:ok, nil} = RodarFeel.eval("5 between x and 10", %{})
    end

    test "null propagation - null high bound" do
      assert {:ok, nil} = RodarFeel.eval("5 between 1 and x", %{})
    end

    test "parses between with expressions" do
      assert {:ok, true} = RodarFeel.eval("5 between 1 + 0 and 5 + 5", %{})
    end
  end

  describe "between parser AST" do
    test "produces between AST node" do
      assert {:ok, {:between, {:literal, 5}, {:literal, 1}, {:literal, 10}}} =
               RodarFeel.Parser.parse("5 between 1 and 10")
    end
  end
end
