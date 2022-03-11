defmodule ExNews.Webserver.Routes do
  @moduledoc """
    ## Overview

    Exposes both HTTP and WebSockets endpoints using cowboy.
  """

  alias ExNews.Webserver.{Handler, WebSocketHandler}

  @type routes ::
          [
            {String.t(), handler :: Module, args :: map}
          ]
  def routes() do
    [
      {"/posts", Handler, %{endpoint: :get_all_posts}},
      {"/post/:id", Handler, %{endpoint: :get_one_post}},
      {"/ws", WebSocketHandler, %{}}
    ]
  end

  # Recompile the routes in runtime
  def recompile() do
    dispatch = :cowboy_router.compile([{:_, routes()}])
    :persistent_term.put(:exnews_dispatch, dispatch)
  end
end
