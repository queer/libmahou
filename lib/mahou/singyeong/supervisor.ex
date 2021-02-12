defmodule Mahou.Singyeong.Supervisor do
  use Supervisor
  alias Mahou.Singyeong

  def start_link(state) do
    Supervisor.start_link __MODULE__, state, name: __MODULE__
  end

  def init({dsn, consumer}) do
    spawn fn ->
      # TODO: lol
      :timer.sleep 100
      start_children Singyeong.child_specs(dsn, consumer)
    end
    Supervisor.init [], strategy: :one_for_one
  end

  def start_children(children) do
    for child <- children, do: Supervisor.start_child __MODULE__, child
    :ok
  end
end
