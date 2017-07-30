defmodule Optium.Parser do
  @moduledoc false

  defstruct keys: MapSet.new, required: MapSet.new, defaults: %{},
            validators: %{}

  @type t :: %__MODULE__{keys: MapSet.t(Optium.key),
                         required: MapSet.t(Optium.key),
                         defaults: %{Optium.key => term},
                         validators: %{Optium.key => Optium.validator}}

  @spec from_schema(Optium.schema) :: t
  def from_schema(schema) do
    Enum.reduce(schema, %__MODULE__{}, &reduce_to_parser/2)
  end

  @spec reduce_to_parser({Optium.key, Optium.validation_opts}, t) :: t
  defp reduce_to_parser({key, opts}, parser)
    when is_atom(key) and is_list(opts) do
    parser
    |> update_keys(key)
    |> update_required(key, opts[:required])
    |> update_defaults(key, Keyword.fetch(opts, :default))
    |> update_validators(key, Keyword.fetch(opts, :validator))
  end

  @spec update_keys(t, Optium.key) :: t
  defp update_keys(parser, key) do
    %__MODULE__{parser | keys: MapSet.put(parser.keys, key)}
  end

  @spec update_required(t, Optium.key, boolean) :: t
  defp update_required(parser, key, true) do
    %__MODULE__{parser | required: MapSet.put(parser.required, key)}
  end
  defp update_required(parser, _, _), do: parser

  @spec update_defaults(t, Optium.key, {:ok, term} | :error) :: t
  defp update_defaults(parser, key, {:ok, default}) do
    %__MODULE__{parser | defaults: Map.put(parser.defaults, key, default)}
  end
  defp update_defaults(parser, _, :error), do: parser

  @spec update_validators(t, Optium.key, {:ok, Optium.validator} | :error) :: t
  defp update_validators(parser, key, {:ok, validator}) do
    validators = Map.put(parser.validators, key, validator)
    %__MODULE__{parser | validators: validators}
  end
  defp update_validators(parser, _, :error), do: parser

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(parser, opts) do
      keys = parser.keys |> MapSet.to_list()

      surround_many("#Optium.Parser<", keys, ">", opts, fn k, _ ->
        inspect(k)
      end)
    end
  end
end
