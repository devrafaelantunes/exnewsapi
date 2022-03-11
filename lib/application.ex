defmodule ExNews.Application do
  use GenServer
  use Application

  @fetch_on_startup Mix.env() != :test
  @fetcher_restart_strategy if(Mix.env() == :test, do: :transient, else: :permanent)

  def start(_type, _args) do
    children = [
      # Starts cowboy with custom args
      cowboy_child_spec(),
      {Task.Supervisor, name: ExNews.TaskSupervisor},

      # Starts the HackerNews Fetcher, State and WebSocketTracker
      fetcher_spec(),
      ExNews.State,
      ExNews.Webserver.WebSocketTracker
    ]

    opts = [strategy: :one_for_one, name: ExNews.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  defp fetcher_spec() do
    opts = %{
      fetch_on_startup: @fetch_on_startup
    }

    %{
      id: :fetcher,
      start: {ExNews.Fetcher, :start_link, [opts]},
      restart: @fetcher_restart_strategy
    }
  end

  defp cowboy_child_spec() do
    dispatch = :cowboy_router.compile([{:_, ExNews.Webserver.Routes.routes()}])
    :persistent_term.put(:exnews_dispatch, dispatch)

    %{
      id: :server,
      start: {
        :cowboy,
        :start_clear,
        [
          :server,
          %{
            socket_opts: [port: 3000],
            max_connections: 16_384,
            num_acceptors: 8
          },
          %{env: %{dispatch: {:persistent_term, :exnews_dispatch}}}
        ]
      },
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor
    }
  end
end
