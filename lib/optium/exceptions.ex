defmodule Optium.Exceptions do
  @moduledoc false

  @spec singular_msg(Optium.key, adj :: String.t) :: String.t
  def singular_msg(key, adj), do: "option #{inspect key} is #{adj}"

  @spec plural_msg([Optium.keys, ...], adj :: String.t) :: String.t
  def plural_msg(keys, adj) do
    [one | many] = keys
    keys_str =
      many
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")
      |> Kernel.<>(" and #{inspect one}")
    "options #{keys_str} are #{adj}"
  end
end

defmodule Optium.OptionMissingError do
  @moduledoc """
  Raised when option marked as `:required` is missing from the options list
  """

  defexception [:keys]

  @type t :: %__MODULE__{keys: [Optium.key, ...]}

  def exception(keys: keys) do
    %__MODULE__{keys: keys}
  end

  def message(struct) do
    keys = struct.keys
    case keys do
      [key] -> Optium.Exceptions.singular_msg(key, "required")
      [_|_] -> Optium.Exceptions.plural_msg(keys, "required")
    end
  end
end

defmodule Optium.OptionInvalidError do
  @moduledoc """
  Raised when option value doesn't comply to given validator function
  """

  defexception [:keys]

  @type t :: %__MODULE__{keys: [Optium.key, ...]}

  def exception(keys: keys) do
    %__MODULE__{keys: keys}
  end

  def message(struct) do
    keys = struct.keys
    case keys do
      [key] -> Optium.Exceptions.singular_msg(key, "invalid")
      [_|_] -> Optium.Exceptions.plural_msg(keys, "invalid")
    end
  end
end
