defmodule ExNews.Webserver.Handler do
  @type request :: map

  def init(request, %{endpoint: :get_all_posts}) do
    request = set_content_type(request)

    qs_params =
      request
      |> :cowboy_req.parse_qs()
      |> Map.new()

    page = parse_integer(qs_params, "page", 1)
    results_per_page = parse_integer(qs_params, "results", 10)

    items = ExNews.State.lookup(page, results_per_page)
    jsonfied_items = Jason.encode!(items)

    {:ok, set_reply(request, jsonfied_items, 200), %{}}
  end

  def init(request, %{endpoint: :get_one_post}) do
    request = set_content_type(request)

    {status, post_id} =
      case Integer.parse(request.bindings.id) do
        {result, _} -> {:ok, result}
        :error -> {:error, nil}
      end

    if status == :ok do
      result = ExNews.State.single_lookup(post_id)

      {status_code, response} =
        if result == nil do
          {404, "post_id not found"}
        else
          {200, Jason.encode!(result)}
        end

      {:ok, set_reply(request, response, status_code), %{}}
    else
      response = "invalid post_id" |> Jason.encode!()

      {:ok, set_reply(request, response, 400), %{}}
    end
  end

  @spec set_content_type(request) ::
          request
  defp set_content_type(request) do
    :cowboy_req.set_resp_header("content-type", "application/json; charset=utf-8", request)
  end

  @spec set_reply(request, body :: String.t(), status_code :: pos_integer) ::
          request
  defp set_reply(request, body, status_code) do
    :cowboy_req.reply(status_code, %{}, body, request)
  end

  @spec parse_integer(qs_params :: map, key :: String.t(), default :: integer) ::
          integer
  defp parse_integer(qs_params, key, default) do
    page = Map.get(qs_params, key, "#{default}")

    case Integer.parse(page) do
      {result, _} -> result
      :error -> default
    end
  end
end
