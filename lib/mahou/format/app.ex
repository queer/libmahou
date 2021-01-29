defmodule Mahou.Format.App do
  use TypedStruct

  typedstruct do
    field :id, String.t() | nil
    field :name, String.t()
    field :namespace, String.t() | nil
    field :image, String.t()
    field :limits, __MODULE__.Limits.t()
    field :env, %{required(String.t() => String.t()}
  end

  typedstruct module: Limits do
    field :cpu, non_neg_integer()
    field :ram, non_neg_integer()
  end
end
