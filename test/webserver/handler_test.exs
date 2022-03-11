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

  defp sample_http_request(qs, path, bindings) do
    %{
      bindings: bindings,
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
      path: path,
      path_info: :undefined,
      peer: {{127, 0, 0, 1}, 63291},
      pid: self(),
      port: 3000,
      qs: qs,
      ref: :server,
      scheme: "http",
      sock: {{127, 0, 0, 1}, 3000},
      streamid: 1,
      version: :"HTTP/1.1"
    }
  end

  describe "init/2 - endpoint: :get_all_posts" do
    test "HTTP Request - returns the entries when it exists" do
      assert [] == StateUtils.get_all_items()
      qs = ""
      path = "/posts"
      bindings = %{}

      entries = [
        %{"id" => 1},
        %{"id" => 2}
      ]

      State.write(entries)

      {:ok, _request, body} =
        Handler.init(sample_http_request(qs, path, bindings), %{endpoint: :get_all_posts})

      assert body == Jason.encode!(entries)
    end

    test "HTTP Request - returns [] when page or entry does not exist" do
      assert [] == StateUtils.get_all_items()
      qs = "page=10"
      path = "/posts"
      bindings = %{}

      {:ok, _request, body} =
        Handler.init(sample_http_request(qs, path, bindings), %{endpoint: :get_all_posts})

      assert body == "[]"
    end
  end

  describe "init/2 - endpoint: :get_one_post" do
    test "HTTP Request - returns the entry when it exists" do
      assert [] == StateUtils.get_all_items()
      qs = ""
      id = "5"
      path = "/post/#{id}"
      bindings = %{id: id}

      entry = [
        %{"id" => String.to_integer(id)}
      ]

      State.write(entry)

      {:ok, _request, body} =
        Handler.init(sample_http_request(qs, path, bindings), %{endpoint: :get_one_post})

      assert body == Jason.encode!(Enum.at(entry, 0))
    end

    test "HTTP Request - returns the entry when it does not exist" do
      assert [] == StateUtils.get_all_items()
      qs = ""
      id = "5"
      path = "/post/#{id}"
      bindings = %{id: id}

      {:ok, _request, body} =
        Handler.init(sample_http_request(qs, path, bindings), %{endpoint: :get_one_post})

      assert body == "[]"
    end
  end
end
