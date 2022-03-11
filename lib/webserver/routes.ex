defmodule ExNews.Webserver.Routes do
  @moduledoc """
    ## Overview

    Exposes both HTTP and WebSockets endpoints using cowboy.
  """

  alias ExNews.Webserver.{Handler, WebSocketHandler}

  @doc """
    Routes available:
    localhost:3000/posts - Lists all top 50 stories
        [OPTIONAL] - You can pass two arguments as a query string:
        page: to determinate the page number
        results: to set the amount of results per page

    localhost:3000/post/:story_id - List a single story based on the given id
    localhost:3000/ws - Create a WebSocket connection to
    recieve the top 50 stories each time it updates
  """
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

  @doc """
    Recompile the routes in runtime
  """
  def recompile() do
    dispatch = :cowboy_router.compile([{:_, routes()}])
    :persistent_term.put(:exnews_dispatch, dispatch)
  end
end
