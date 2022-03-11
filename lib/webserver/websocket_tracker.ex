defmodule ExNews.Webserver.WebSocketTracker do
  @moduledoc """
    ## Overview

    This GenServer is used to track the connected WebSockets PID's via an ETS table.
    Its goal is to broadcast the stories to all the connected PIDS.

    ## How it works

    The WebSocketTracker gets the pid when the WebSocket first connects, then 
    it stores its value on an ETS table. Once the connection ends, the tracker 
    deletes the PID from the table.

    ## Future improvements

    The `:ets.match_delete` can be a possible botteneck in case we have thousands of 
    active websockets connections. This happens because the function's query need to 
    iterate over all the active connections to find the one that needs to be deleted. 
  """

  use GenServer

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
    # Fetch the current PIDS stored on the ETS Table
    :ets.lookup(@table_name, :ws_connections)
    |> Enum.map(fn {_, v} -> v end)
  end

  def init(_) do
    # Starts the ETS table based on the `@table_name`
    :ets.new(@table_name, [:named_table, :bag, :protected, read_concurrency: true])

    {:ok, %{}}
  end

  def handle_call({:track, pid}, _from, state) do
    # Adds the PID to the table upon connection
    :ets.insert(@table_name, {:ws_connections, pid})

    {:reply, :ok, state}
  end

  def handle_call({:kill, pid}, _from, state) do
    # Deletes the PID to the table upon disconnection
    :ets.match_delete(@table_name, {:ws_connections, pid})
    {:reply, :ok, state}
  end
end
