defmodule Mahou.Docs do
  use TypedStruct
  # alias Mahou.Docs.JsonSchema

  @docs_key "mahou:singyeong:#{Mahou.Singyeong.metadata_version()}:metadata:docs"

  @type http_method() ::
    :get
    | :post
    | :put
    | :patch
    | :delete
    | :head
    | :options

  @type module_guess() ::
    :controller
    | :consumer
    | :unknown

  defmacro __using__(_) do
    quote do
      use Annotatable, [:input, :output]

      def __mahou_docs__ do
        what_am_i = Mahou.Docs.guess_what_this_is __MODULE__

        # language-level docs
        function_docs =
          case Code.fetch_docs(__MODULE__) do
            {:docs_v1, _, _lang, _mime, _module, _, function_docs} ->
              function_docs

            _ -> []
          end

        function_docs =
          function_docs
          |> Enum.reject(fn
            {{:function, _func, _arity}, _, _spec, :hidden, _} -> true
            {{:function, _func, _arity}, _, _spec, :none, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {{:function, func, _arity}, _, _, docs, _} ->
            # TODO: Other languages?
            {func, docs["en"]}
          end)
          |> Map.new

        # %{:function => {module, kind()}}
        # TODO: Could we do compile-time validation?
        mahou_docs =
        case what_am_i do
          :consumer ->
            __MODULE__.annotations()
            |> Enum.map(fn {function, annotations} ->
              new_annotations =
                annotations
                |> Enum.map(fn %{annotation: ann, value: val}-> {ann, val} end)
                |> Map.new

              {function, new_annotations}
            end)
            |> Enum.filter(fn {_, annotations} ->
              # Consumers and controllers aren't allowed in the same module
              Map.has_key?(annotations, :input) and not Map.has_key?(annotations, :output)
            end)
            |> Enum.map(fn {function, annotations} ->
              case annotations[:input] do
                mod when is_atom(mod) ->
                  {function, %{
                    type: :push,
                    input: mod,
                    docs: function_docs[function],
                  }}

                {mod, queue} when is_atom(mod) and is_binary(queue) ->
                  {function, %{
                    type: :queue,
                    queue: queue,
                    input: mod,
                    docs: function_docs[function],
                  }}

                wtf -> __mahou_docs_raise_helper(:consumer, :input, function, wtf)
              end
            end)
            |> Map.new

          :controller ->
            __MODULE__.annotations()
            |> Enum.filter(fn {_, annotations} ->
              Map.has_key?(annotations, :input) and Map.has_key?(annotations, :output)
            end)
            |> Enum.map(fn {function, annotations} ->
              case {annotations[:input], annotations[:output]} do
                {input, output} when is_atom(input) and is_atom(output) ->
                  {function, %{
                    type: :http,
                    input: input,
                    output: output,
                    docs: function_docs[function],
                  }}

                wtf -> __mahou_docs_raise_helper(:controller, :io, function, wtf)
              end
            end)
            |> Map.new

          :unknown -> nil
        end
      end

      defp __mahou_docs_raise_helper(type, kind, function, wtf) do
        raise """
        #{type}: #{__MODULE__}.#{function}: invalid #{kind}: #{inspect wtf, pretty: true}
        """
      end
    end
  end

  def generate do
    documented_mods =
      fn mod -> Kernel.function_exported?(mod, :__mahou_docs__, 0) end
      |> all_mods_where
      # At this point, we have everything that uses this module
      |> Enum.map(fn mod -> {mod, mod.__mahou_docs__()} end)
      |> Map.new

    routers =
      fn mod -> Kernel.function_exported?(mod, :__routes__, 0) end
      |> all_mods_where
      |> Enum.map(&{&1, &1.__routes__()})
      |> Map.new

    consumers = Enum.filter documented_mods, fn {mod, _} -> guess_what_this_is(mod) == :consumer end

    controllers =
      routers
      |> Map.values
      |> Enum.map(&{&1.plug, &1})
      |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
      |> Map.new

    controller_docs =
      controllers
      |> Enum.filter(fn {mod, _} -> Map.has_key?(documented_mods, mod) end)
      |> Enum.map(fn {mod, meta} -> {mod, meta, documented_mods[mod]} end)
      |> Enum.map(fn {_, meta, functions} ->
        Enum.map functions, fn {function, %{input: input, output: output} = data} ->
          route =
            meta
            |> Enum.filter(fn route -> route.plug_opts == function end)
            |> hd

          {Atom.to_string(input), %{
            data
            | input: peek_json(input),
              output: peek_json(output),
              http: %{
                method: route.verb,
                path: route.path,
              },
          }}
        end
      end)

    # TODO: Add route, method, etc. info to controllers

    consumer_docs =
      consumers
      |> Enum.map(fn {_, functions} ->
        Enum.map functions, fn {_function, %{input: input} = data} ->
          {Atom.to_string(input), %{data | input: peek_json(input)}}
        end
      end)
      |> List.flatten
      |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
      |> Map.new

    message_docs = consumer_docs ++ controller_docs

    transports =
      message_docs
      |> Enum.map(fn {mod, docs} ->
        {mod, Enum.map(docs, fn doc ->
          case doc[:type] do
            :push -> :push
            # Can't have tuples in JSON
            :queue -> [:queue, doc[:queue]]
            _ -> doc[:type]
          end
        end)}
      end)
      |> Map.new

    %{
      type: "map",
      value: %{
        docs: message_docs,
        transports: transports,
      },
    }
  end

  defp all_mods_where(query) do
    :code.all_available()
    |> Enum.map(fn {mod, _, _} -> mod |> to_string |> String.to_atom end)
    |> Enum.filter(query)
  end

  defp peek_json(value) do
    struct_hack = Map.from_struct value.__struct__()
    version = struct_hack[:version] || struct_hack[:v] || 0
    %{
      name: Atom.to_string(value),
      version: version,
      types: Peek.peek(value, json: true),
    }
  end

  @doc """
  The singyeong metadata key that docs are stored under
  """
  def docs_key, do: @docs_key

  @spec guess_what_this_is(Module.t()) :: module_guess()
  def guess_what_this_is(module) do
    attrs = module.module_info()[:attributes]
    cond do
      attrs[:phoenix_callback] != nil -> :controller
      attrs[:phoenix_forwards] != nil -> :router
      is_list(attrs[:behaviour]) and Singyeong.Consumer in attrs[:behaviour] -> :consumer
      true -> :unknown
    end
  end
end
