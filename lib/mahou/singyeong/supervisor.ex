defmodule Mahou.Singyeong.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link __MODULE__, :ok, name: __MODULE__
  end

  def init(_) do
    Supervisor.init [], strategy: :one_for_one
  end

  def start_children(children) do
    for child <- children, do: Supervisor.start_child __MODULE__, child
    :ok
  end
end
