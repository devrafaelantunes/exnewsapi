defmodule ExNews.Webserver.WebSocketTracker do
  use GenServer

  # Smell: ver se tem forma melhor de fazer esse tracking. Talvez algum Registry

  @table_name :ws_tracker

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec track(pid()) :: term
  def track(pid) do
    GenServer.call(__MODULE__, {:track, pid})
  end

  @spec kill(pid()) :: term
  def kill(pid) do
    GenServer.call(__MODULE__, {:kill, pid})
  end

  @spec get_connected_pids() :: [pid()]
  def get_connected_pids do
    :ets.lookup(@table_name, :ws_connections)
    |> Enum.map(fn {_, v} -> v end)
  end

  def init(_) do
    :ets.new(@table_name, [:named_table, :bag, :protected, read_concurrency: true])

    {:ok, %{}}
  end

  def handle_call({:track, pid}, _from, state) do
    :ets.insert(@table_name, {:ws_connections, pid})

    {:reply, :ok, state}
  end

  def handle_call({:kill, pid}, _from, state) do
    :ets.match_delete(@table_name, {:ws_connections, pid})
    {:reply, :ok, state}
  end
end
