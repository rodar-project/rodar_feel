defmodule RodarFeel.FunctionsTest do
  use ExUnit.Case, async: true

  alias RodarFeel.Functions

  describe "numeric functions" do
    test "abs" do
      assert {:ok, 5} = Functions.call("abs", [-5])
      assert {:ok, 5} = Functions.call("abs", [5])
      assert {:ok, 3.14} = Functions.call("abs", [-3.14])
    end

    test "floor" do
      assert {:ok, 3} = Functions.call("floor", [3.7])
      assert {:ok, -4} = Functions.call("floor", [-3.2])
    end

    test "ceiling" do
      assert {:ok, 4} = Functions.call("ceiling", [3.2])
      assert {:ok, -3} = Functions.call("ceiling", [-3.7])
    end

    test "round with no scale" do
      assert {:ok, 4} = Functions.call("round", [3.7])
      assert {:ok, 3} = Functions.call("round", [3.2])
    end

    test "round with scale" do
      assert {:ok, 3.1} = Functions.call("round", [3.14, 1])
      assert {:ok, 3.15} = Functions.call("round", [3.145, 2])
    end

    test "min" do
      assert {:ok, 1} = Functions.call("min", [[3, 1, 2]])
      assert {:ok, nil} = Functions.call("min", [[]])
    end

    test "max" do
      assert {:ok, 3} = Functions.call("max", [[3, 1, 2]])
      assert {:ok, nil} = Functions.call("max", [[]])
    end

    test "sum" do
      assert {:ok, 6} = Functions.call("sum", [[1, 2, 3]])
      assert {:ok, 0} = Functions.call("sum", [[]])
    end

    test "count" do
      assert {:ok, 3} = Functions.call("count", [[1, 2, 3]])
      assert {:ok, 0} = Functions.call("count", [[]])
    end
  end

  describe "string functions" do
    test "string length" do
      assert {:ok, 5} = Functions.call("string length", ["hello"])
      assert {:ok, 0} = Functions.call("string length", [""])
    end

    test "contains" do
      assert {:ok, true} = Functions.call("contains", ["hello world", "world"])
      assert {:ok, false} = Functions.call("contains", ["hello", "world"])
    end

    test "starts with" do
      assert {:ok, true} = Functions.call("starts with", ["hello", "he"])
      assert {:ok, false} = Functions.call("starts with", ["hello", "lo"])
    end

    test "ends with" do
      assert {:ok, true} = Functions.call("ends with", ["hello", "lo"])
      assert {:ok, false} = Functions.call("ends with", ["hello", "he"])
    end

    test "upper case" do
      assert {:ok, "HELLO"} = Functions.call("upper case", ["hello"])
    end

    test "lower case" do
      assert {:ok, "hello"} = Functions.call("lower case", ["HELLO"])
    end

    test "substring with start" do
      assert {:ok, "llo"} = Functions.call("substring", ["hello", 3])
    end

    test "substring with start and length" do
      assert {:ok, "ll"} = Functions.call("substring", ["hello", 3, 2])
    end
  end

  describe "boolean functions" do
    test "not true returns false" do
      assert {:ok, false} = Functions.call("not", [true])
    end

    test "not false returns true" do
      assert {:ok, true} = Functions.call("not", [false])
    end

    test "not nil returns nil" do
      assert {:ok, nil} = Functions.call("not", [nil])
    end
  end

  describe "null functions" do
    test "is null with nil" do
      assert {:ok, true} = Functions.call("is null", [nil])
    end

    test "is null with value" do
      assert {:ok, false} = Functions.call("is null", [42])
      assert {:ok, false} = Functions.call("is null", [""])
      assert {:ok, false} = Functions.call("is null", [false])
    end
  end

  describe "null propagation" do
    test "numeric functions return nil for nil arg" do
      assert {:ok, nil} = Functions.call("abs", [nil])
      assert {:ok, nil} = Functions.call("floor", [nil])
      assert {:ok, nil} = Functions.call("ceiling", [nil])
      assert {:ok, nil} = Functions.call("round", [nil])
      assert {:ok, nil} = Functions.call("min", [nil])
      assert {:ok, nil} = Functions.call("max", [nil])
      assert {:ok, nil} = Functions.call("sum", [nil])
      assert {:ok, nil} = Functions.call("count", [nil])
    end

    test "string functions return nil for nil arg" do
      assert {:ok, nil} = Functions.call("string length", [nil])
      assert {:ok, nil} = Functions.call("contains", [nil, "x"])
      assert {:ok, nil} = Functions.call("contains", ["x", nil])
      assert {:ok, nil} = Functions.call("starts with", [nil, "x"])
      assert {:ok, nil} = Functions.call("ends with", ["x", nil])
      assert {:ok, nil} = Functions.call("upper case", [nil])
      assert {:ok, nil} = Functions.call("lower case", [nil])
    end

    test "lists with nil elements propagate nil for sum" do
      assert {:ok, nil} = Functions.call("sum", [[1, nil, 3]])
    end

    test "lists with nil elements propagate nil for min/max" do
      assert {:ok, nil} = Functions.call("min", [[1, nil, 3]])
      assert {:ok, nil} = Functions.call("max", [[1, nil, 3]])
    end
  end

  describe "new string functions" do
    test "split" do
      assert {:ok, ["a", "b", "c"]} = Functions.call("split", ["a,b,c", ","])
      assert {:ok, ["hello"]} = Functions.call("split", ["hello", ","])
    end

    test "substring before" do
      assert {:ok, "hello"} = Functions.call("substring before", ["hello world", " "])
      assert {:ok, ""} = Functions.call("substring before", ["hello", " "])
    end

    test "substring after" do
      assert {:ok, "world"} = Functions.call("substring after", ["hello world", " "])
      assert {:ok, ""} = Functions.call("substring after", ["hello", " "])
    end

    test "replace" do
      assert {:ok, "herro"} = Functions.call("replace", ["hello", "l", "r"])
      assert {:ok, "hello"} = Functions.call("replace", ["hello", "x", "y"])
    end

    test "trim" do
      assert {:ok, "hello"} = Functions.call("trim", ["  hello  "])
      assert {:ok, "hello"} = Functions.call("trim", ["hello"])
    end

    test "null propagation for new string functions" do
      assert {:ok, nil} = Functions.call("split", [nil, ","])
      assert {:ok, nil} = Functions.call("split", ["a", nil])
      assert {:ok, nil} = Functions.call("substring before", [nil, " "])
      assert {:ok, nil} = Functions.call("substring after", [nil, " "])
      assert {:ok, nil} = Functions.call("replace", [nil, "a", "b"])
      assert {:ok, nil} = Functions.call("replace", ["a", nil, "b"])
      assert {:ok, nil} = Functions.call("replace", ["a", "a", nil])
      assert {:ok, nil} = Functions.call("trim", [nil])
    end
  end

  describe "list functions" do
    test "append" do
      assert {:ok, [1, 2, 3]} = Functions.call("append", [[1, 2], 3])
    end

    test "concatenate" do
      assert {:ok, [1, 2, 3]} = Functions.call("concatenate", [[1], [2], [3]])
      assert {:ok, [1, 2, 3, 4]} = Functions.call("concatenate", [[1, 2], [3, 4]])
    end

    test "reverse" do
      assert {:ok, [3, 2, 1]} = Functions.call("reverse", [[1, 2, 3]])
      assert {:ok, []} = Functions.call("reverse", [[]])
    end

    test "flatten" do
      assert {:ok, [1, 2, 3, 4]} = Functions.call("flatten", [[[1, 2], [3, [4]]]])
    end

    test "distinct values" do
      assert {:ok, [1, 2, 3]} = Functions.call("distinct values", [[1, 2, 1, 3]])
    end

    test "sort" do
      assert {:ok, [1, 2, 3]} = Functions.call("sort", [[3, 1, 2]])
    end

    test "index of" do
      assert {:ok, [2, 4]} = Functions.call("index of", [[1, 2, 3, 2], 2])
      assert {:ok, []} = Functions.call("index of", [[1, 2, 3], 5])
    end

    test "list contains" do
      assert {:ok, true} = Functions.call("list contains", [[1, 2, 3], 2])
      assert {:ok, false} = Functions.call("list contains", [[1, 2, 3], 5])
    end

    test "null propagation for list functions" do
      assert {:ok, nil} = Functions.call("append", [nil, 1])
      assert {:ok, nil} = Functions.call("concatenate", [nil, [1]])
      assert {:ok, nil} = Functions.call("reverse", [nil])
      assert {:ok, nil} = Functions.call("flatten", [nil])
      assert {:ok, nil} = Functions.call("distinct values", [nil])
      assert {:ok, nil} = Functions.call("sort", [nil])
      assert {:ok, nil} = Functions.call("index of", [nil, 1])
      assert {:ok, nil} = Functions.call("list contains", [nil, 1])
    end
  end

  describe "conversion functions" do
    test "string from number" do
      assert {:ok, "42"} = Functions.call("string", [42])
      assert {:ok, "3.14"} = Functions.call("string", [3.14])
    end

    test "string from boolean" do
      assert {:ok, "true"} = Functions.call("string", [true])
      assert {:ok, "false"} = Functions.call("string", [false])
    end

    test "string from string (identity)" do
      assert {:ok, "hello"} = Functions.call("string", ["hello"])
    end

    test "string from nil" do
      assert {:ok, nil} = Functions.call("string", [nil])
    end

    test "string from list" do
      assert {:ok, "[1, 2, 3]"} = Functions.call("string", [[1, 2, 3]])
    end
  end

  describe "boolean aggregate functions" do
    test "all with all true" do
      assert {:ok, true} = Functions.call("all", [[true, true, true]])
    end

    test "all with some false" do
      assert {:ok, false} = Functions.call("all", [[true, false, true]])
    end

    test "all three-valued with nil" do
      assert {:ok, nil} = Functions.call("all", [[true, nil, true]])
      assert {:ok, false} = Functions.call("all", [[false, nil, true]])
    end

    test "any with some true" do
      assert {:ok, true} = Functions.call("any", [[false, true, false]])
    end

    test "any with all false" do
      assert {:ok, false} = Functions.call("any", [[false, false, false]])
    end

    test "any three-valued with nil" do
      assert {:ok, nil} = Functions.call("any", [[false, nil, false]])
      assert {:ok, true} = Functions.call("any", [[true, nil, false]])
    end
  end

  describe "new numeric functions" do
    test "product" do
      assert {:ok, 24} = Functions.call("product", [[1, 2, 3, 4]])
      assert {:ok, 1} = Functions.call("product", [[]])
    end

    test "product with nil" do
      assert {:ok, nil} = Functions.call("product", [nil])
      assert {:ok, nil} = Functions.call("product", [[1, nil, 3]])
    end

    test "mean" do
      {:ok, result} = Functions.call("mean", [[1, 2, 3]])
      assert_in_delta result, 2.0, 0.001
    end

    test "mean of empty list" do
      assert {:ok, nil} = Functions.call("mean", [[]])
    end

    test "mean with nil" do
      assert {:ok, nil} = Functions.call("mean", [nil])
      assert {:ok, nil} = Functions.call("mean", [[1, nil, 3]])
    end
  end

  describe "error cases" do
    test "unknown function returns error" do
      assert {:error, "unknown FEEL function: foobar"} = Functions.call("foobar", [42])
    end
  end
end
