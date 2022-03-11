defmodule ExNews.Webserver.WebSocketHandler do
  @moduledoc """
    ## Overview

    Uses cowboy to handle the WebSockets connections. It integrates with the WebSocketTracker module to
    keep track and broadcast the stories' updates.
  """

  @behaviour :cowboy_websocket

  alias ExNews.Webserver.WebSocketTracker

  # Cowboy config opts
  @cowboy_opts %{
    idle_timeout: 61_000,
    max_frame_size: 1_000_000,
    compress: false
  }

  def init(req, _state) do
    {:cowboy_websocket, req, %{req: req}, @cowboy_opts}
  end

  def websocket_init(%{req: _req}) do
    # Start tracking the connected PID
    WebSocketTracker.track(self())

    # Fetch the current top 50
    current_top50 =
      ExNews.State.lookup(1, 50)
      |> Jason.encode!()

    # Send the current top 50 to the connected PID
    Process.send(self(), {:push, current_top50}, [])
    {:ok, %{}}
  end

  def websocket_handle({:text, _payload}, state) do
    {:ok, state}
  end

  def websocket_info({:push, payload}, state) do
    {:reply, {:text, payload}, state}
  end

  def terminate(_reason, _req, _state) do
    # Terminates the connection
    WebSocketTracker.kill(self())
  end
end
