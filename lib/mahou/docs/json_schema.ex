defmodule Mahou.Format.JsonSchema do
  def of(module, type \\ :t) when is_atom(module) do
    json = GenJsonSchema.gen module, type
    # Will raise if invalid schema
    ExJsonSchema.resolve json
    {:ok, json}
  end
end
