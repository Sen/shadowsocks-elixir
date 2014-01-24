defmodule Local do
  def listen(port) do
    tcp_options = [:binary, {:packet, 0}, {:active, :once}, {:reuseaddr, true},
      {:keepalive, true}]
    {:ok, l_socket} = :gen_tcp.listen(port, tcp_options)
    do_listen(l_socket)
  end

  def do_listen(l_socket) do
    {:ok, socket} = :gen_tcp.accept(l_socket)
    pid = spawn(fn() -> do_server(socket) end)
    :gen_tcp.controlling_process(socket, pid)
    do_listen(l_socket)
  end

  def do_server(socket) do
    :inet.setopts(socket, [{:active, :once}])
    receive do
      {:tcp, socket, << 5, 1, 0 >>} ->
        :ok = :gen_tcp.send(socket, << 5, 0 >>)

        do_server(socket)
      {:tcp, socket, data} ->
        << _ver, cmd, _rsv, address_type, rest :: binary >> = data
        case cmd do
          1 -> # scucess
            {:ok, remote_socket} = :gen_tcp.connect('127.0.0.1', 8388,
              [:binary, {:packet, :raw}, {:active, :once}])
            pid = spawn_link(fn() -> do_remote(remote_socket, socket) end)
            :gen_tcp.controlling_process(remote_socket, pid)

            case address_type do
              1 -> # ip address
                IO.puts "ip"
                :ok = :gen_tcp.send(remote_socket, String.slice(data, 4..9))

              3 -> # domain address
                << addr_len, _ :: binary >> = rest
                :ok = :gen_tcp.send(remote_socket, String.slice(data, 3..5 + addr_len + 2))
                #to_send = String.slice(data, 5 + addr_len + 3..-1)
              _ ->
                IO.puts "address type not support"
                :ok = :gen_tcp.close(socket)
            end

            :ok = :gen_tcp.send(socket, << 5, 0, 0, 1, 0, 0, 0, 0 >> <> integer_to_binary(8388, 16))
            do_server(socket, remote_socket)
          _ ->
            :ok = :gen_tcp.send(socket, << 5, 7, 0, 1 >>)
            :ok = :gen_tcp.close(socket)
        end

      {:tcp_closed, socket} ->
        :ok
    end
  end

  def do_server(socket, remote_socket) do
    :inet.setopts(socket, [{:active, :once}])
    receive do
      {:tcp, socket, data} ->
        :ok = :gen_tcp.send(remote_socket, data)
        do_server(socket, remote_socket)

      {:tcp_closed, socket} ->
        :ok
    end
  end

  def do_remote(remote_socket, socket) do
    :inet.setopts(remote_socket, [{:active, :once}])
    receive do
      {:tcp, remote_socket, data} ->
        case :gen_tcp.send(socket, data) do
          :ok ->
            do_remote(remote_socket, socket)
          {:error, :closed } ->
            :ok
        end

      {:tcp_closed, remote_socket} ->
        :ok
    end
  end
end
