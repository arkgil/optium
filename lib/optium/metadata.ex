defmodule Optium.Metadata do
  @moduledoc false

  defstruct keys: MapSet.new, required: MapSet.new, defaults: %{},
            validators: %{}

  @type t :: %__MODULE__{keys: MapSet.t(Optium.key),
                         required: MapSet.t(Optium.key),
                         defaults: %{Optium.key => term},
                         validators: %{Optium.key => Optium.validator}}

  @spec from_schema(Optium.schema) :: t
  def from_schema(schema) do
    Enum.reduce(schema, %__MODULE__{}, &reduce_to_metadata/2)
  end

  @spec reduce_to_metadata({Optium.key, Optium.key_opts}, t) :: t
  defp reduce_to_metadata({key, opts}, metadata)
    when is_atom(key) and is_list(opts) do
    metadata
    |> update_keys(key)
    |> update_required(key, opts[:required])
    |> update_defaults(key, Keyword.fetch(opts, :default))
    |> update_validators(key, Keyword.fetch(opts, :validator))
  end

  @spec update_keys(t, Optium.key) :: t
  defp update_keys(metadata, key) do
    %__MODULE__{metadata | keys: MapSet.put(metadata.keys, key)}
  end

  @spec update_required(t, Optium.key, boolean) :: t
  defp update_required(metadata, key, true) do
    %__MODULE__{metadata | required: MapSet.put(metadata.required, key)}
  end
  defp update_required(metadata, _, _), do: metadata

  @spec update_defaults(t, Optium.key, {:ok, term} | :error) :: t
  defp update_defaults(metadata, key, {:ok, default}) do
    %__MODULE__{metadata | defaults: Map.put(metadata.defaults, key, default)}
  end
  defp update_defaults(metadata, _, :error), do: metadata

  @spec update_validators(t, Optium.key, {:ok, Optium.validator} | :error) :: t
  defp update_validators(metadata, key, {:ok, validator}) do
    validators = Map.put(metadata.validators, key, validator)
    %__MODULE__{metadata | validators: validators}
  end
  defp update_validators(metadata, _, :error), do: metadata
end
