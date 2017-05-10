defmodule OptiumTest do
  use ExUnit.Case
  doctest Optium

  describe "parse/2" do
    test "returns only options defined in schema" do
      schema = %{key1: [],
                 key2: [required: true]}
      opts = [key1: 1, key2: 2, key3: 3]
      keys = Map.keys(schema)

      {:ok, parsed} = Optium.parse(opts, schema)

      assert length(parsed) == length(keys)
      assert Keyword.fetch(parsed, :key1) == {:ok, 1}
      assert Keyword.fetch(parsed, :key2) == {:ok, 2}
      assert Keyword.fetch(parsed, :key3) == :error
    end
  end
end
