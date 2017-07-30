defmodule Optium.ParserTest do
  use ExUnit.Case

  alias Optium.Parser

  describe "from_schema/1" do
    test "saves all keys in :keys set" do
      schema = %{key1: [required: true],
                 key2: [default: 3],
                 key3: []}
      keys = Map.keys(schema)

      parser = Parser.from_schema(schema)

      for key <- keys do
        assert MapSet.member?(parser.keys, key)
      end
    end

    test "saves all keys marked as :required in :required set" do
      schema = %{key1: [required: true, default: 3],
                 key2: [required: false],
                 key3: [],
                 key4: [required: true]}
      required_keys = [:key1, :key4]

      parser = Parser.from_schema(schema)

      for key <- required_keys do
        assert MapSet.member?(parser.required, key)
      end
    end

    test "saves all default values in :defaults map" do
      schema = %{key1: [required: true, default: 3],
                 key2: [],
                 key3: [default: nil]}

      parser = Parser.from_schema(schema)

      assert Map.fetch(parser.defaults, :key1) == {:ok, 3}
      assert Map.fetch(parser.defaults, :key2) == :error
      assert Map.fetch(parser.defaults, :key3) == {:ok, nil}
    end
  end
end
