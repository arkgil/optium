defmodule OptiumTest do
  use ExUnit.Case
  doctest Optium

  alias Optium.{OptionMissingError, OptionInvalidError}

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

    test "takes defult values if options are not present" do
      schema = %{key1: [default: 3],
                 key2: [default: 4],
                 key3: []}
      opts = [key2: 2]

      {:ok, parsed} = Optium.parse(opts, schema)

      assert Keyword.fetch(parsed, :key1) == {:ok, 3}
      assert Keyword.fetch(parsed, :key2) == {:ok, 2}
      assert Keyword.fetch(parsed, :key3) == :error
    end

    test "returns {:error, _} tuple in case of missing :required option" do
      schema = %{key1: [required: true],
                 key2: [required: true],
                 key3: [required: true]}
      opts = [key1: 1]

      assert {:error, error} = Optium.parse(opts, schema)

      assert %OptionMissingError{keys: keys} = error
      assert length(keys) == 2
      assert :key2 in keys
      assert :key3 in keys
    end

    test "return {:error, _} tuple in case of invalid option value" do
      schema = %{key: [validator: &is_binary/1]}
      opts = [key: 1]

      assert {:error, error} = Optium.parse(opts, schema)

      assert %OptionInvalidError{key: :key} == error
    end

    test "returns options if values comply to validators" do
      schema = %{key: [validator: &is_binary/1]}
      opts = [key: "alicehasacat"]

      assert {:ok, ^opts} = Optium.parse(opts, schema)
    end

    test "raises ArgumentError if validator doesn't return a boolean" do
      schema = %{key: [validator: fn _ -> :ok end]}
      opts = [key: "alicehasacat"]

      assert_raise ArgumentError, fn ->
        Optium.parse(opts, schema)
      end
    end
  end

  describe "parse!/2" do
    test "raises an exception when something goes wrong" do
      schema = %{key1: [required: true],
                 key2: [required: true],
                 key3: []}
      opts = [key1: 1, key3: 3]

      assert_raise OptionMissingError, fn ->
        Optium.parse!(opts, schema)
      end
    end
  end

  describe "exception messages" do
    test "singular OptionMissingError" do
      exception = %OptionMissingError{keys: [:key]}

      assert Exception.message(exception) ==
        "option :key is required"
    end

    test "plural OptionMissingError" do
      exception = %OptionMissingError{keys: [:key1, :key2, :key3]}

      assert Exception.message(exception) ==
        "options :key2, :key3 and :key1 are required"
    end
  end
end
