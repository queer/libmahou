defmodule Mahou.Message do
  use TypedStruct
  alias Mahou.Message.{ChangeContainerStatus, CreateContainer}

  typedstruct do
    field :ts, non_neg_integer()
    field :msg, ChangeContainerStatus.t()
                | CreateContainer.t()
  end
end
