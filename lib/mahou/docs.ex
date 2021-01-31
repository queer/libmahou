defmodule Mahou.Docs do
  defmacro __using__(_) do
    quote do
      use Annotatable, [:in, :out]
      alias Mahou.Docs.JsonSchema

      def __mahou_doc_types__() do
        __MODULE__.annotations()
        |> Enum.filter(fn {_, annotations} ->
          Map.has_key?(annotations, :in) or Map.has_key?(annotations, :out)
        end)
        |> Enum.map(fn {function, annotations} ->
          {function, annotations[:in], annotations[:out]}
        end)
      end
    end
  end
end
