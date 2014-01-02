defmodule Server do
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
      { :ok, data } ->
        << addr_type, addr_len, rest :: binary >> = data

        case addr_type do
          1 -> # ip
            IO.puts "ip"
          3 -> # domain
            addr_bytes = addr_len * 8
            << remote_addr :: size(addr_bytes), remote_port :: size(16), to_send :: binary >> = rest
            {:ok, remote_addr_list} = String.to_char_list << remote_addr :: size(addr_bytes) >>
          _ ->
            IO.puts "address type not support"
            :ok = :gen_tcp.close(socket)
        end

        {:ok, request_socket} = :gen_tcp.connect(remote_addr_list, remote_port, [:binary, {:packet, 0}, {:active, false}])
        spawn_link(fn() -> do_request(request_socket, socket) end)
        request_sender_pid = spawn_link(fn() -> do_request_sender(request_socket) end)

        if String.length(to_send) > 0 do
          request_sender_pid <- { :send, to_send }
        end

        do_server(socket, request_sender_pid)
      { :error, :closed } -> :ok
    end
  end

  def do_server(socket, request_sender_pid) do
    case :gen_tcp.recv(socket, 0) do
      { :ok, data } ->
        request_sender_pid <- { :send, data }
        do_server(socket, request_sender_pid)
      { :error, :closed } ->
        request_sender_pid <- { :close }
        :ok
    end
  end

  def do_request_sender(socket) do
    receive do
      { :send, data } ->
        :ok = :gen_tcp.send(socket, data)
        do_request_sender(socket)
      { :close } ->
        :ok = :gen_tcp.close(socket)
    end
  end

  def do_request(request_socket, socket) do
    case :gen_tcp.recv(request_socket, 0) do
      { :ok, data } ->
        :ok = :gen_tcp.send(socket, data)
        do_request(request_socket, socket)

      { :error, :closed } ->
        :ok = :gen_tcp.close(request_socket)
        :ok = :gen_tcp.close(socket)
        :ok
    end
  end

end
