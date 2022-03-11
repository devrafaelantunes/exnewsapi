defmodule ExNews.Webserver.Handler do
  @moduledoc """
    ## Overview

    Uses cowboy to handles HTTP's requests. 

    ## How it works

    Returns the top 50 stories list based on the page and results per page. 
    The user can also search for an individual story included on the list, based on its id.
  """

  @type request :: map

  @doc """
    localhost:3000/posts
    :get_all_posts endpoint

    List the top 50 HN's stories

    It can recieve two arguments passed as query string:
      page: to determinate the page number
      results: to set the amount of results displayed by page

    The arguments are optional. If none is provided, the default values will take its place.

    It returns a list of HN's stories ranked by score, it can also return an empty array [] in
    case no stories were found
  """
  def init(request, %{endpoint: :get_all_posts}) do
    # Set the request content_type to JSON
    request = set_content_type(request)

    # Parse the params
    qs_params =
      request
      |> :cowboy_req.parse_qs()
      |> Map.new()

    # The default `page` value is set to 1
    page = parse_integer(qs_params, "page", 1)
    # The default `results_per_page` value is set to 10
    results_per_page = parse_integer(qs_params, "results", 10)

    # Lookup the results in the State
    items = ExNews.State.lookup(page, results_per_page)
    jsonfied_items = Jason.encode!(items)

    {:ok, set_reply(request, jsonfied_items, 200), jsonfied_items}
  end

  @doc """
    localhost:3000/post/:id
    :get_one_post endpoint

    List a single HN's story

    It expects the id as a parameter, example:
    - localhost:3000/post/5

    If the story is available inside of the current Top 50 stories, its info will be returned,
    otherwise you'll get a 404 error indicating that the story was not found 
  """
  def init(request, %{endpoint: :get_one_post}) do
    request = set_content_type(request)

    # Parse the post_id recieved as an argument
    {status, post_id} =
      case Integer.parse(request.bindings.id) do
        {result, _} -> {:ok, result}
        :error -> {:error, nil}
      end

    # If the parse was successful
    if status == :ok do
      result = ExNews.State.single_lookup(post_id)

      {status_code, response} =
        if result == nil do
          {404, "post_id not found"}
        else
          {200, Jason.encode!(result)}
        end

      {:ok, set_reply(request, response, status_code), response}
    else
      # If the parse failed
      response = "invalid post_id" |> Jason.encode!()

      {:ok, set_reply(request, response, 400), response}
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
