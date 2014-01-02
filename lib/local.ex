defmodule Local do
  def listen(port) do
    tcp_options = [:binary, {:packet, 0}, {:active, false}, {:reuseaddr, true}]
    {:ok, l_socket} = :gen_tcp.listen(port, tcp_options)
    do_listen(l_socket)
  end

  def do_listen(l_socket) do
    {:ok, socket} = :gen_tcp.accept(l_socket)
    spawn(fn() -> do_server(socket) end)
    do_listen(l_socket)
  end

  def do_server(socket) do
    case :gen_tcp.recv(socket, 0) do
      { :ok, << 5, 1, 0 >> } ->
        :ok = :gen_tcp.send(socket, << 5, 0 >>)

        do_server(socket)
      { :ok, data } ->
        << _ver, cmd, _rsv, address_type, rest :: binary >> = data
        case cmd do
          1 -> # scucess
            {:ok, remote_socket} = :gen_tcp.connect('localhost', 8388, [:binary, {:packet, 0}, {:active, false}])
            spawn_link(fn() -> do_remote(remote_socket, socket) end)
            remote_sender_pid = spawn_link(fn() -> do_remote_sender(remote_socket) end)

            case address_type do
              1 -> # ip address
                remote_sender_pid <- { :send, String.slice(data, 4..9) }

              3 -> # domain address
                << addr_len, _ :: binary >> = rest
                remote_sender_pid <- { :send, String.slice(data, 3..5 + addr_len + 2) }
              _ ->
                IO.puts "address type not support"
                :ok = :gen_tcp.close(socket)
            end

            :ok = :gen_tcp.send(socket, << 5, 0, 0, 1, 0, 0, 0, 0 >> <> integer_to_binary(8388, 16))
            do_server(socket, remote_sender_pid)
          _ ->
            :ok = :gen_tcp.send(socket, << 5, 7, 0, 1 >>)
            :ok = :gen_tcp.close(socket)
            Process.exit(self, :exit)
        end

      _ ->
        :ok = :gen_tcp.close(socket)
    end
  end

  def do_server(socket, remote_sender_pid) do
    case :gen_tcp.recv(socket, 0) do
      { :ok, data } ->
        remote_sender_pid <- { :send, data }
        do_server(socket, remote_sender_pid)

      { :error, :closed } ->
        Process.exit(self, :exit)
        :ok
    end
  end

  def do_remote_sender(socket) do
    receive do
      { :send, data } ->
        :ok = :gen_tcp.send(socket, data)
        do_remote_sender(socket)
    end
  end

  def do_remote(remote_socket, socket) do
    case :gen_tcp.recv(remote_socket, 0) do
      { :ok, data } ->
        :ok = :gen_tcp.send(socket, data)
        do_remote(remote_socket, socket)

      { :error, :closed } ->
        :ok = :gen_tcp.close(remote_socket)
        :ok = :gen_tcp.close(socket)

        :ok
    end
  end
end
