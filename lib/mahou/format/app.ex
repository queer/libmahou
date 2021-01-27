defmodule Mahou.Format.App do
  use TypedStruct

  typedstruct do
    field :id, String.t() | nil
    field :name, String.t()
    field :image, String.t()
    field :limits, __MODULE__.Limits.t()
  end

  typedstruct module: Limits do
    field :cpu, non_neg_integer()
    field :ram, non_neg_integer()
  end
end
