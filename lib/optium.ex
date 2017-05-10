defmodule Optium do
  @moduledoc """
  Functions for validating optional arguments passed to your functions

  To validate options with Optium, you need to provide it a option schema.
  Schema is a map or a keyword list describing how each option should be
  validated.

  ## Examples

      %{port: [required: true],
        address: [required: true, default: {0, 0, 0, 0}]}

  Based on the schema above, Optium knows that `:port` option is required,
  and it  will return an `Optium.OptionMissingError` if it is not provided.
  `:address` is also required, but by defining a default value you make sure
  that no errors will be returned and that default value will be appended
  to parsed options list instead. Use `Optium.parse/2` to parse and validate
  options:

      iex> schema = %{port:    [required: true],
      ...>            address: [required: true, default: {0, 0, 0, 0}]}
      iex> [port: 12_345, address: {127, 0, 0, 1}] |> Optium.parse(schema)
      {:ok, [port: 12_345, address: {127, 0, 0, 1}]}
      iex> [port: 12_345] |> Optium.parse(schema)
      {:ok, [address: {0, 0, 0, 0}, port: 12_345]}
      iex> [address: {127, 0, 0, 1}] |> Optium.parse(schema)
      {:error, %Optium.OptionMissingError{key: :port}}

  There is also `Optium.parse!/2`, which follows Elixir's convention of "bang
  functions" and raises and error instead of returning it.

      iex> schema = %{port:    [required: true],
      ...>            address: [required: true, default: {0, 0, 0, 0}]}
      iex> [address: {127, 0, 0, 1}] |> Optium.parse!(schema)
      ** (Optium.OptionMissingError) option :port is required

  ## Schema

  Schemas are keyword lists or maps with atoms as keys, and validation
  options lists as values. Currently two validation options are supported:
  `:required` and `:default`. When option is `:required`, `parse/2` returns
  `Optium.OptionMissingError` if it is not present in the provided options list.
  This can be overriden by providing `:default` value, which is put into
  provided options list if no such option is present.

  Note that returned, validated options list contains only those options which
  keys are present in the schema. You can add an option to schema with empty
  validation options list (like `%{key: []}`), but it doesn't make much sense
  because you most likely want to have some default value anyway.

  ## Error handling

  As mentioned before, `parse/2` returns `{:error, error}` tuple, where `error`
  is a relevant exception struct. All Optium exceptions implement
  `Exception.message/1` callback, so you can use `Exception.message(error)`
  to provide nice error message to users of your function. `parse!/2` intercepts
  exception structs and raises them instead of returning.
  """

  alias Optium.Metadata

  @type key :: atom
  @type opts :: Keyword.t
  @type schema :: %{key => key_opts} | [{key, key_opts}]
  @type key_opts :: [key_opt]
  @type key_opt :: [{:required, boolean}, {:default, term}]
  @type error :: OptionMissingError.t

  @doc """
  Parses, validates and normalizes options based on passed Optium schema

  See documentation for `Optium` module for more info.
  """
  @spec parse(opts, schema) :: {:ok, opts} | {:error, error}
  def parse(opts, schema) do
    metadata = Optium.Metadata.from_schema(schema)

      opts
      |> take_defined_options(metadata)
      |> add_defaults(metadata)
      |> assert_required_options(metadata)
  end

  @doc """
  Same as `parse/2`, but raises an exception instead of returning it
  """
  @spec parse!(opts, schema) :: opts | no_return
  def parse!(opts, schema) do
    case parse(opts, schema) do
      {:ok, parsed}   -> parsed
      {:error, error} -> raise error
    end
  end

  @spec take_defined_options(opts, Metadata.t) :: opts
  defp take_defined_options(opts, metadata) do
    Enum.reduce(metadata.keys, [], fn key, acc ->
      maybe_take_opt(key, opts, acc)
    end)
  end

  @spec maybe_take_opt(key, opts, acc :: opts) :: acc :: opts
  defp maybe_take_opt(key, opts, acc) do
    case Keyword.fetch(opts, key) do
      {:ok, value} ->
        Keyword.put(acc, key, value)
      _ ->
        acc
    end
  end

  @spec add_defaults(opts, Metadata.t) :: opts
  defp add_defaults(opts, metadata) do
    Enum.reduce(metadata.defaults, opts, fn {key, default}, acc ->
      maybe_add_default(acc, key, default)
    end)
  end

  @spec maybe_add_default(opts, key, default :: term) :: opts
  defp maybe_add_default(opts, key, default) do
    case Keyword.fetch(opts, key) do
      :error ->
        Keyword.put(opts, key, default)
      _ ->
        opts
    end
  end

  @spec assert_required_options(opts, Metadata.t)
    :: {:ok, opts} | {:error, OptionMissingError.t}
  defp assert_required_options(opts, metadata) do
    check_required_opts(metadata.required |> MapSet.to_list(), opts)
  end

  @spec check_required_opts([key], opts)
    :: {:ok, opts} | {:error, OptionMissingError.t}
  defp check_required_opts([key | rest], opts) do
    if Keyword.has_key?(opts, key) do
      check_required_opts(rest, opts)
    else
      {:error, Optium.OptionMissingError.exception(key)}
    end
  end
  defp check_required_opts([], opts), do: {:ok, opts}

  defmodule OptionMissingError do
    @moduledoc """
    Raised when option marked as `:required` is missing from the options list
    """

    defexception [:key]

    @type t :: %__MODULE__{key: Optium.key}

    def exception(key) do
      %__MODULE__{key: key}
    end

    def message(struct) do
      "option #{inspect struct.key} is required"
    end
  end
end
