defmodule Mix.Tasks.Remote do
  use Mix.Task

  def run(_) do
    IO.puts "Server side is up, port:8388"
    Server.listen(8388)
  end
end
