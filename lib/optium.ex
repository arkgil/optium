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
      {:error, %Optium.OptionMissingError{keys: [:port]}}
      iex> [port: "12_345"] |> Optium.parse(schema)
      {:error, %Optium.OptionInvalidError{keys: [:port]}}

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

  ### Schema compilation

  When schema is not constructed dynamically (which I believe is the most
  common scenario), you can compile it into a parser to avoid unnecessary
  processing in every call to `parse/2`:

      @schema %{key: [default: 1]}
      @parser Optium.compile(@schema)

      def my_fun(opts) do
        opts
        |> Optium.parse!(@parser)
        |> do_stuff()
      end

  ## Error handling

  As mentioned before, `parse/2` returns `{:error, error}` tuple, where `error`
  is a relevant exception struct. All Optium exceptions implement
  `Exception.message/1` callback, so you can use `Exception.message(error)`
  to provide nice error message to users of your functions. `parse!/2` intercepts
  exception structs and raises them instead of returning.
  """

  alias Optium.Parser
  alias Optium.{OptionMissingError, OptionInvalidError}

  @type key :: atom
  @type opts :: Keyword.t
  @type schema :: %{key => validation_opts} | [{key, validation_opts}]
  @opaque parser :: Optium.Parser.t
  @type validator :: (value :: term -> boolean)
  @type validation_opts :: [validation_opt]
  @type validation_opt :: {:required, boolean}
                        | {:default, term}
                        | {:validator, validator}
  @type error :: OptionMissingError.t | OptionInvalidError.t

  @doc """
  Compiles the schema into a parser
  """
  @spec compile(schema) :: parser
  def compile(schema) do
    Optium.Parser.from_schema(schema)
  end

  @doc """
  Parses, validates and normalizes options using provided parser or schema

  See documentation for `Optium` module for more info.
  """
  @spec parse(opts, parser | schema) :: {:ok, opts} | {:error, error}
  def parse(opts, %Optium.Parser{} = parser) do
    opts =
      opts
      |> take_defined_options(parser)
      |> add_defaults(parser)

    with {:ok, opts} <- assert_required_options(opts, parser),
         {:ok, opts} <- validate_options(opts, parser) do
      {:ok, opts}
    end
  end
  def parse(opts, schema) do
    parser = Optium.Parser.from_schema(schema)
    parse(opts, parser)
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

  @spec take_defined_options(opts, Parser.t) :: opts
  defp take_defined_options(opts, parser) do
    Enum.reduce(parser.keys, [], fn key, acc ->
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

  @spec add_defaults(opts, Parser.t) :: opts
  defp add_defaults(opts, parser) do
    Enum.reduce(parser.defaults, opts, fn {key, default}, acc ->
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

  @spec assert_required_options(opts, Parser.t)
    :: {:ok, opts} | {:error, OptionMissingError.t}
  defp assert_required_options(opts, parser) do
    check_required_opts(parser.required |> MapSet.to_list(), opts)
  end

  @spec check_required_opts([key], opts)
    :: {:ok, opts} | {:error, OptionMissingError.t}
  @spec check_required_opts([key], opts, missing :: [key])
    :: {:ok, opts} | {:error, OptionMissingError.t}
  defp check_required_opts(keys, opts, missing \\ [])
  defp check_required_opts([key | rest], opts, missing) do
    missing =
      if Keyword.has_key?(opts, key) do
        missing
      else
        [key | missing]
      end
    check_required_opts(rest, opts, missing)
  end
  defp check_required_opts([], opts, []), do: {:ok, opts}
  defp check_required_opts([], _, missing) do
    {:error, OptionMissingError.exception(keys: missing)}
  end

  @spec validate_options(opts, Parser.t)
    :: {:ok, opts} | {:error, OptionInvalidError.t}
  defp validate_options(opts, parser) do
    ensure_opts_valid(parser.validators |> Enum.to_list(), opts)
  end

  @spec ensure_opts_valid([{key, validator}], opts)
    :: {:ok, opts} | {:error, OptionInvalidError.t}
  @spec ensure_opts_valid([{key, validator}], opts, invalid :: [key])
    :: {:ok, opts} | {:error, OptionInvalidError.t}
  defp ensure_opts_valid(validators, opts, invalid \\ [])
  defp ensure_opts_valid([{key, validator} | rest], opts, invalid) do
    with {:ok, value} <- Keyword.fetch(opts, key),
         :valid       <- run_validator(validator, value) do
      ensure_opts_valid(rest, opts, invalid)
    else
      :error ->
        ensure_opts_valid(rest, opts, invalid)
      :invalid ->
        ensure_opts_valid(rest, opts, [key | invalid])
    end
  end
  defp ensure_opts_valid([], opts, []), do: {:ok, opts}
  defp ensure_opts_valid([], _, invalid) do
    {:error, OptionInvalidError.exception(keys: invalid)}
  end

  @spec run_validator(validator, value :: term) :: :valid | :invalid
  defp run_validator(validator, value) do
    case validator.(value) do
      true  -> :valid
      false -> :invalid
      _ ->
        raise ArgumentError, "Optium validator must return a boolean"
    end
  end
end
