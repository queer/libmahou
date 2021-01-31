defmodule Mahou.Singyeong do
  def child_specs(dsn, consumer) when is_binary(dsn) and is_atom(consumer) do
    [
      {Singyeong.Client, Singyeong.parse_dsn(dsn)},
      Singyeong.Producer,
      consumer,
    ]
  end
end
