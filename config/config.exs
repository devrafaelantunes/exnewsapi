import Config

config :exnews,
  hn_api: ExNews.API,
  hn_api_base_url: "https://hacker-news.firebaseio.com/v0"

import_config "#{config_env()}.exs"
