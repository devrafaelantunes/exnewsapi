defmodule ExNews.Test.HandlerTest do
  use ExUnit.Case, async: true

  alias ExNews.Webserver.Handler

  alias ExNews.Test.{StateUtils}
  alias ExNews.{State}

  setup do
    on_exit(fn ->
      StateUtils.wipe_state()
    end)

    :ok
  end

  @sample_request %{
    bindings: %{},
    body_length: 0,
    cert: :undefined,
    has_body: false,
    headers: %{
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "accept-encoding" => "gzip, deflate",
      "accept-language" => "en-us",
      "connection" => "keep-alive",
      "host" => "localhost:3000",
      "upgrade-insecure-requests" => "1",
      "user-agent" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 Safari/605.1.15"
    },
    host: "localhost",
    host_info: :undefined,
    method: "GET",
    path: "/posts",
    path_info: :undefined,
    peer: {{127, 0, 0, 1}, 63291},
    pid: self(),
    port: 3000,
    qs: "",
    ref: :server,
    scheme: "http",
    sock: {{127, 0, 0, 1}, 3000},
    streamid: 1,
    version: :"HTTP/1.1"
  }

  describe "init/2" do
    test "HTTP Request - returns the entries when it exists" do
      assert [] == StateUtils.get_all_items()

      entries = [
        %{"id" => 1},
        %{"id" => 2}
      ]

      State.write(entries)

      {:ok, _request, body} = Handler.init(@sample_request, %{endpoint: :get_all_posts})

      assert body == Jason.encode!(entries)
    end

    test "HTTP Request - returns [] when page or entry does not exist" do
      assert [] == StateUtils.get_all_items()

      sample_request = Map.put(@sample_request, :qs, "page=10")

      {:ok, _request, body} = Handler.init(sample_request, %{endpoint: :get_all_posts})

      assert body == "[]"
    end
  end
end
