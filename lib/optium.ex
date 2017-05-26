defmodule Optium do
  @moduledoc """
  Functions for validating arguments passed in keyword lists

  To validate options with Optium, you need to provide it a option schema.
  Schema is a map or a keyword list describing how each option should be
  validated.

  ## Examples

      %{port: [required: true, validator: &is_integer/1],
        address: [required: true, default: {0, 0, 0, 0}]}

  Based on the schema above, Optium knows that `:port` option is required,
  and it  will return an `Optium.OptionMissingError` if it is not provided.
  It will also check if provided `:port` is an integer, and return
  `Optium.OptionInvalidError` if it is not.
  `:address` is also required, but by defining a default value you make sure
  that no errors will be returned and that default value will be appended
  to parsed options list instead. Use `Optium.parse/2` to parse and validate
  options:

      iex> schema = %{port:    [required: true, validator: &is_integer/1],
      ...>            address: [required: true, default: {0, 0, 0, 0}]}
      iex> [port: 12_345, address: {127, 0, 0, 1}] |> Optium.parse(schema)
      {:ok, [port: 12_345, address: {127, 0, 0, 1}]}
      iex> [port: 12_345] |> Optium.parse(schema)
      {:ok, [address: {0, 0, 0, 0}, port: 12_345]}
      iex> [address: {127, 0, 0, 1}] |> Optium.parse(schema)
      {:error, %Optium.OptionMissingError{key: :port}}
      iex> [port: "12_345"] |> Optium.parse(schema)
      {:error, %Optium.OptionInvalidError{key: :port}}

  There is also `Optium.parse!/2`, which follows Elixir's convention of "bang
  functions" and raises and error instead of returning it.

      iex> schema = %{port:    [required: true, validator: &is_integer/1],
      ...>            address: [required: true, default: {0, 0, 0, 0}]}
      iex> [address: {127, 0, 0, 1}] |> Optium.parse!(schema)
      ** (Optium.OptionMissingError) option :port is required

  ## Schema

  Schemas are keyword lists or maps with atoms as keys, and validation
  options lists as values.

  Supported validation options:
  * `:required` - `parse/2` returns `Optium.OptionMissingError` if options
    is not present in the provided options list.
  * `:default` - this value will be put into provided options list if the
    corresponding key is missing. Overrides `:required`.
  * `:validator` - a function which takes an option's value, and returns
    `true` if it is valid, or `false` otherwise. If validator returns
    a non-boolean, `parse/2` will raise `ArgumentError`. `:default`
    values will be validated too.

  Note that returned, validated options list contains only those options which
  keys are present in the schema. You can add an option to schema with empty
  validation options list (like `%{key: []}`), but it doesn't make much sense
  because you most likely want to have some default value anyway.

  ## Error handling

  As mentioned before, `parse/2` returns `{:error, error}` tuple, where `error`
  is a relevant exception struct. All Optium exceptions implement
  `Exception.message/1` callback, so you can use `Exception.message(error)`
  to provide nice error message to users of your functions. `parse!/2` intercepts
  exception structs and raises them instead of returning.
  """

  alias Optium.Metadata
  alias __MODULE__.{OptionMissingError, OptionInvalidError}

  @type key :: atom
  @type opts :: Keyword.t
  @type schema :: %{key => validation_opts} | [{key, validation_opts}]
  @type validator :: (value :: term -> boolean)
  @type validation_opts :: [validation_opt]
  @type validation_opt :: {:required, boolean}
                        | {:default, term}
                        | {:validator, validator}
  @type error :: OptionMissingError.t | OptionInvalidError.t

  @doc """
  Parses, validates and normalizes options based on passed Optium schema

  See documentation for `Optium` module for more info.
  """
  @spec parse(opts, schema) :: {:ok, opts} | {:error, error}
  def parse(opts, schema) do
    metadata = Optium.Metadata.from_schema(schema)

    opts =
      opts
      |> take_defined_options(metadata)
      |> add_defaults(metadata)

    with {:ok, opts} <- assert_required_options(opts, metadata),
         {:ok, opts} <- validate_options(opts, metadata) do
      {:ok, opts}
    end
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
      {:error, OptionMissingError.exception(key: key)}
    end
  end
  defp check_required_opts([], opts), do: {:ok, opts}

  @spec validate_options(opts, Metadata.t)
    :: {:ok, opts} | {:error, OptionInvalidError.t}
  defp validate_options(opts, metadata) do
    ensure_opts_valid(metadata.validators |> Enum.to_list(), opts)
  end

  @spec ensure_opts_valid([{key, validator}], opts)
    :: {:ok, opts} | {:error, OptionInvalidError.t}
  defp ensure_opts_valid([{key, validator} | rest], opts) do
    with {:ok, value} <- Keyword.fetch(opts, key),
         :valid       <- run_validator(validator, value) do
      ensure_opts_valid(rest, opts)
    else
      :error ->
        ensure_opts_valid(rest, opts)
      :invalid ->
        {:error, OptionInvalidError.exception(key: key)}
    end
  end
  defp ensure_opts_valid([], opts), do: {:ok, opts}

  @spec run_validator(validator, value :: term) :: :valid | :invalid
  defp run_validator(validator, value) do
    case validator.(value) do
      true  -> :valid
      false -> :invalid
      _ ->
        raise ArgumentError, "Optium validator must return a boolean"
    end
  end

  defmodule OptionMissingError do
    @moduledoc """
    Raised when option marked as `:required` is missing from the options list
    """

    defexception [:key]

    @type t :: %__MODULE__{key: Optium.key}

    def exception(key: key) do
      %__MODULE__{key: key}
    end

    def message(struct) do
      "option #{inspect struct.key} is required"
    end
  end

  defmodule OptionInvalidError do
    @moduledoc """
    Raised when option value doesn't comply to given validator function
    """

    defexception [:key]

    @type t :: %__MODULE__{key: Optium.key}

    def exception(key: key) do
      %__MODULE__{key: key}
    end

    def message(struct) do
      "option #{inspect struct.key} is invalid"
    end
  end
end
