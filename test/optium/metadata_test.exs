defmodule Optium.MetadataTest do
  use ExUnit.Case

  alias Optium.Metadata

  describe "from_schema/1" do
    test "saves all keys in :keys set" do
      schema = %{key1: [required: true],
                 key2: [default: 3],
                 key3: []}
      keys = Map.keys(schema)

      metadata = Metadata.from_schema(schema)

      for key <- keys do
        assert MapSet.member?(metadata.keys, key)
      end
    end

    test "saves all keys marked as :required in :required set" do
      schema = %{key1: [required: true, default: 3],
                 key2: [required: false],
                 key3: [],
                 key4: [required: true]}
      required_keys = [:key1, :key4]

      metadata = Metadata.from_schema(schema)

      for key <- required_keys do
        assert MapSet.member?(metadata.required, key)
      end
    end

    test "saves all default values in :defaults map" do
      schema = %{key1: [required: true, default: 3],
                 key2: [],
                 key3: [default: nil]}

      metadata = Metadata.from_schema(schema)

      assert Map.fetch(metadata.defaults, :key1) == {:ok, 3}
      assert Map.fetch(metadata.defaults, :key2) == :error
      assert Map.fetch(metadata.defaults, :key3) == {:ok, nil}
    end
  end
end
