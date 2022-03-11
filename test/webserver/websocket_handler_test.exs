defmodule ExNews.Webserver.WebSocketHandlerTest do
  @moduledoc """
    WIP.

    This module is still in development.
    My plan is to test the WebSocketHandler following the same pattern I used in the `ExNews.FetcherTest` module.

    I would instantiate the WebSocketHandler's GenServer to check if the Handler is storing the
    connections properly, it would also be necessary to Stop the GenServer to test if the connection
    is removed from the active connections table.
  """
end
