defmodule ExNews.Fetcher do
  @moduledoc """
    ## Overview

    This module is responsible for making HTTP requests to the HackerNews API using HTTPoison
    to fetch the current top 50 stories. 

    It is also responsible for broadcasting the stories to the connected WebSockets.

    The GenServer is used to create a 5 minute timer, which works as the requests' interval.

    ## How it works
    
    The module spawns an isolated process for each request it makes. 
    All the individual stories are processed and fetched concurrently, based on the `@max_concurrency`. 
    If the API is down, it will retry the request until reaches the max attemps defined in the API module.
    If the retries do not work and an error still happens while fetching an individual story, 
    it won't be recorded.  

    Due to the isolation of each process, if any error happens the process will restart itself 
    without interfering with the others. 

    The children tasks are also supervised.

    The module will only write the stories in memory if the request was sucessful.

    As a trade-off, I chose to always make a request to fetch the current top 50 stories instead of
    creating a cache system to check if the request was really necessary. I opted for this approach, 
    based on the frequency the score updates.

    ## Broadcasting to the connected WebSockets

    The function `broadcast_new_stories` broadcasts the stories when they are updated. It gets the 
    connected pids and sends a message to the Websocket Handler GenServer, broadcasting the stories.
  """

  use GenServer
  require Logger
  alias ExNews.{State}

  # 5 minutes interval
  @interval 5 * 60_000
  @timeout 5_000

  @max_concurrency if Mix.env() == :test, do: 1, else: :erlang.system_info(:schedulers)

  @api Application.get_env(:exnews, :hn_api)

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Starts the initial 5 minute timer
    Process.send_after(self(), :fetch_hn, get_interval(opts))

    {:ok, %{opts: opts}, {:continue, :initial_request}}
  end

  def handle_continue(:initial_request, state) do
    if get_config(state.opts, :fetch_on_startup) do
      fetch_stories_wrapper()
    else
      Logger.debug("Skipping initial fetching because of `fetch_on_startup` flag.")
    end

    {:noreply, state}
  end

  def handle_info(:fetch_hn, state) do
    # Keeps reactivacting the timer
    Process.send_after(self(), :fetch_hn, get_interval(state.opts))

    # Fetch the results
    result = fetch_stories_wrapper()

    # Broadcast the results to the connected WebSockets
    broadcast_new_stories(result)

    {:noreply, state}
  end

  @spec fetch_stories_wrapper() ::
          [State.story()]
  defp fetch_stories_wrapper() do
    task =
      Task.Supervisor.async_nolink(ExNews.TaskSupervisor, fn ->
        fetch_stories()
      end)

    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      {:exit, _} ->
        []

      nil ->
        Logger.warn("Failed to get a result in #{@timeout}")
        []
    end
  end

  @spec broadcast_new_stories([State.story()]) :: term
  defp broadcast_new_stories([]), do: :noop

  defp broadcast_new_stories(stories) do
    task =
      Task.Supervisor.async_nolink(ExNews.TaskSupervisor, fn ->
        # Get the connected WebSockets' PID
        connected_ws_pids = ExNews.Webserver.WebSocketTracker.get_connected_pids()

        top50_stories_serialized = stories |> Jason.encode!()

        Task.async_stream(connected_ws_pids, fn pid ->
          send(pid, {:push, top50_stories_serialized})
        end)
        |> Stream.run()
      end)

    Task.yield(task, @timeout) || Task.shutdown(task)
  end

  @spec fetch_stories() ::
          [State.story()]
  def fetch_stories() do
    # Use the API module to make a request. It can also use Mox for tests
    {:ok, payload} = @api.get("/topstories.json?print=pretty")
    top50 = Enum.slice(payload, 0..49)

    Task.async_stream(
      top50,
      fn item_id ->
        case @api.get("/item/#{item_id}.json?print=pretty") do
          {:ok, payload} ->
            # Drop some useless info about the story
            Map.drop(payload, ["descendants", "kids", "time", "type", "text"])

          :error ->
            :error
        end
      end,
      max_concurrency: @max_concurrency
    )
    |> Enum.to_list()
    |> Enum.map(fn
      {_, :error} -> nil
      {_, v} -> v
    end)
    # Filter out request from items that failed
    |> Enum.reject(&is_nil/1)
    |> State.write()
  end

  @spec get_config(map, atom, term) :: term
  defp get_config(opts, key, default \\ true) do
    case opts[key] do
      nil -> default
      v -> v
    end
  end

  @spec get_interval(map) :: integer
  defp get_interval(opts),
    do: get_config(opts, :interval, @interval)
end
