defmodule ExNews.Fetcher do
  @moduledoc """

  """

  use GenServer
  require Logger
  alias ExNews.{State}

  # @interval 5 * 60_000
  @timeout 5_000
  @interval 5_000

  @max_concurrency if Mix.env() == :test, do: 1, else: :erlang.system_info(:schedulers)

  @api Application.get_env(:exnews, :hn_api)

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
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
    Process.send_after(self(), :fetch_hn, get_interval(state.opts))

    result = fetch_stories_wrapper()

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
    {:ok, payload} = @api.get("/topstories.json?print=pretty")
    top50 = Enum.slice(payload, 0..49)

    Task.async_stream(
      top50,
      fn item_id ->
        case @api.get("/item/#{item_id}.json?print=pretty") do
          {:ok, payload} ->
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
