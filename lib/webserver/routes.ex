defmodule ExNews.Webserver.Routes do
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

  # Reinicia as rotas em tempo real sem precisar de CTLR C 
  def recompile() do
    dispatch = :cowboy_router.compile([{:_, routes()}])
    :persistent_term.put(:exnews_dispatch, dispatch)
  end
end
