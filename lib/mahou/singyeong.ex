defmodule Mahou.Singyeong do
  def child_specs(dsn, consumer) when is_binary(dsn) and is_atom(consumer) do
    [
      {Singyeong.Client, {guess_internal_ip(), Singyeong.parse_dsn(dsn)}},
      Singyeong.Producer,
      consumer,
    ]
  end

  def guess_internal_ip do
    super_secret_docker_bypass? = System.get_env("__DO_NOT_RUN_THIS_IN_DOCKER_OR_YOU_WILL_BE_FIRED_INTO_THE_SUN") != nil

    # TODO: THIS DOES NOT SUPPORT IPv6
    :inet.getifaddrs()
    |> elem(1)
    |> Enum.reject(fn
      # Reject obvious loopbacks
      {'lo', _} -> true
      {_, [{:flags, flags} | _]} -> :loopback in flags
      {_ifname, opts} ->
        # If it doesn't have an addr, that means it's probably not used, even
        # tho it might be up
        missing_addr? = not Keyword.has_key? opts, :addr

        # If the if has a 169.254.x.x address, DHCP is kabork and you
        # probably shouldn't trust it
        no_dhcp_addr? =
          if Keyword.has_key?(opts, :addr) do
            {one, two, _, _} = Keyword.get opts, :addr
            one == 169 and two == 254
          else
            false
          end

        # Docker traditionally (seems to?) use the 172.16.0.0 - 172.31.255.255
        # range for containers/ its own ifs, so we try to avoid that.
        docker_addr? =
          if Keyword.has_key?(opts, :addr) and not super_secret_docker_bypass? do
            {one, two, _, _} = Keyword.get opts, :addr
            one == 172 and (two >= 16 and two <= 31)
          else
            false
          end

        is_not_internal? =
          case Keyword.get(opts, :addr, nil) do
            {192, 168, _, _} -> false
            {10, _, _, _} -> false
            {172, x, _, _} when x >= 16 and x <= 31 and super_secret_docker_bypass? -> false
            _ -> true
          end

        Enum.any? [missing_addr?, no_dhcp_addr?, docker_addr?, is_not_internal?]
    end)
    |> hd
    |> elem(1)
    |> Keyword.get(:addr)
    |> tuple_to_ip
  end

  defp tuple_to_ip({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end
end
