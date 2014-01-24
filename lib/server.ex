defmodule Server do
  def listen(port) do
    tcp_options = [:binary, {:packet, 0}, {:active, :once}, {:reuseaddr, true}, {:backlog, 128}]
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
      {:tcp, socket, data} ->
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

        {:ok, request_socket} = :gen_tcp.connect(remote_addr_list, remote_port, [:binary, {:packet, 0}, {:active, :once}])
        pid = spawn_link(fn() -> do_request(request_socket, socket) end)
        :gen_tcp.controlling_process(request_socket, pid)
        request_sender_pid = spawn_link(fn() -> do_request_sender(request_socket) end)

        if String.length(to_send) > 0 do
          send(request_sender_pid, { :send, to_send })
        end

        do_server(socket, request_sender_pid)
      {:tcp_closed, socket} -> :ok
    end
  end

  def do_server(socket, request_sender_pid) do
    :inet.setopts(socket, [{:active, :once}])
    receive do
      {:tcp, socket, data} ->
        send(request_sender_pid, { :send, data })
        do_server(socket, request_sender_pid)
      {:tcp_closed, socket} -> :ok
    end
  end

  def do_request_sender(socket) do
    receive do
      { :send, data } ->
        case :gen_tcp.send(socket, data) do
          :ok ->
            do_request_sender(socket)
          { :error, :closed } -> :ok
        end
    end
  end

  def do_request(request_socket, socket) do
    :inet.setopts(request_socket, [{:active, :once}])
    receive do
      {:tcp, request_socket, data} ->
        case :gen_tcp.send(socket, data) do
          :ok ->
            do_request(request_socket, socket)
          { :error, :closed } -> :ok
        end

      {:tcp_closed, request_socket} -> :ok
    end
  end

end
