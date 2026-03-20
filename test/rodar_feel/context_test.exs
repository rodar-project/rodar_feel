defmodule RodarFeel.ContextTest do
  use ExUnit.Case, async: true

  describe "context literals" do
    test "parses empty context" do
      assert {:ok, %{}} = RodarFeel.eval("{}", %{})
    end

    test "parses single entry context" do
      assert {:ok, %{"a" => 1}} = RodarFeel.eval("{a: 1}", %{})
    end

    test "parses multi-entry context" do
      assert {:ok, %{"a" => 1, "b" => 2}} = RodarFeel.eval("{a: 1, b: 2}", %{})
    end

    test "context with string keys" do
      assert {:ok, %{"name" => "Alice"}} =
               RodarFeel.eval(~S({"name": "Alice"}), %{})
    end

    test "context with expression values" do
      assert {:ok, %{"sum" => 3}} = RodarFeel.eval("{sum: 1 + 2}", %{})
    end

    test "context entries can reference previous entries" do
      assert {:ok, %{"a" => 1, "b" => 2}} = RodarFeel.eval("{a: 1, b: a + 1}", %{})
    end

    test "context entries can reference bindings" do
      assert {:ok, %{"greeting" => "hello"}} =
               RodarFeel.eval("{greeting: name}", %{"name" => "hello"})
    end

    test "context with nested context" do
      assert {:ok, %{"inner" => %{"x" => 1}}} =
               RodarFeel.eval("{inner: {x: 1}}", %{})
    end
  end

  describe "context parser AST" do
    test "produces context AST node" do
      assert {:ok, {:context, [{"a", {:literal, 1}}, {"b", {:literal, 2}}]}} =
               RodarFeel.Parser.parse("{a: 1, b: 2}")
    end

    test "empty context AST" do
      assert {:ok, {:context, []}} = RodarFeel.Parser.parse("{}")
    end
  end
end
