defmodule Mix.Tasks.Client do
  use Mix.Task

  def run(_) do
    IO.puts "Local side is up, port:1080"
    Local.listen(1080)
  end
end
