defmodule Optium do
  @moduledoc """
  Functions for validating optional arguments passed to your functions
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
  """
  @spec parse(opts, schema) :: {:ok, opts} | {:error, error}
  def parse(opts, schema) do
    metadata = Optium.Metadata.from_schema(schema)

      opts
      |> take_defined_options(metadata)
      |> add_defaults(metadata)
      |> assert_required_options(metadata)
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
