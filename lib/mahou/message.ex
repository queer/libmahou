defmodule Mahou.Message do
  use TypedStruct
  alias Mahou.Message.{ChangeContainerStatus, CreateContainer}

  typedstruct do
    field :ts, non_neg_integer()
    field :payload, ChangeContainerStatus.t()
                    | CreateContainer.t()
  end

  def create(payload) do
    %__MODULE__{
      ts: :os.system_time(:millisecond),
      payload: payload,
    }
    |> :erlang.term_to_binary
  end

  def parse(payload), do: :erlang.binary_to_term payload
end
