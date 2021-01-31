defmodule Mahou.Docs do
  use TypedStruct
  alias Mahou.Docs.JsonSchema

  @docs_key "mahou:singyeong:metadata:docs"

  @type http_method() ::
    :get
    | :post
    | :put
    | :patch
    | :delete
    | :head
    | :options

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
          {function, {annotations[:in], annotations[:out]}}
        end)
        |> Map.new
      end
    end
  end

  typedstruct module: Msg do
    field :desc, String.t() | nil
    field :schema, map()
  end

  typedstruct module: Route do
    field :route, String.t()
    field :method, Mahou.Docs.http_method()
    field :in, [Mahou.Docs.Msg.t()]
    field :out, [Mahou.Docs.Msg.t()]
  end

  typedstruct module: Metadata do
    field :in, [Mahou.Docs.Msg.t()] | []
    field :out, [Mahou.Docs.Msg.t()] | []
    field :routes, [Mahou.Docs.Route.t()] | []
  end

  @doc """
  Generates mahou-compatible, singyeong-metadata-formatted documentation for
  this application.

  ## Options

  - `:phx_routers`: A list of Phoenix routers to automatically generate
    documentation from.
  - `:input_messages`: `module | {module, desc}`s that this application can
    receive.
  - `:output_messages`: `module | {module, desc}`s that this application can
    send.
  """
  @spec docs_metadata(Keyword.t()) :: __MODULE__.Metadata.t()
  def docs_metadata(opts) do
    routers = Keyword.get opts, :phx_routers, []
    input = Keyword.get opts, :input_messages, []
    output = Keyword.get opts, :output_messages, []

    %__MODULE__.Metadata{
      in: Enum.map(input, &to_msg/1),
      out: Enum.map(output, &to_msg/1),
      routes: Enum.flat_map(routers, &to_routes/1),
    }
  end

  @doc """
  The singyeong metadata key that docs are stored under
  """
  def docs_key, do: @docs_key

  defp to_msg(module) when is_atom(module) do
    %__MODULE__.Msg{desc: nil, schema: JsonSchema.of(module)}
  end
  defp to_msg({module, desc}) when is_atom(module) and is_binary(desc) do
    %__MODULE__.Msg{desc: desc, schema: JsonSchema.of(module)}
  end

  defp to_routes(router) do
    router.__routes__()
    |> Enum.map(&Map.from_struct/1)
    |> Enum.map(fn %{verb: verb, path: path, plug: plug, plug_opts: plug_opts} ->
      {inputs, outputs} = Map.get plug.__mahou_doc_types__(), plug_opts
      %__MODULE__.Route{
        route: path,
        method: verb,
        in: Enum.map(inputs, &to_msg/1),
        out: Enum.map(outputs, &to_msg/1),
      }
    end)
  end
end
