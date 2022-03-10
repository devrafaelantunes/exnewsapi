defmodule ExNews.API do
  require Logger

  @base_url Application.get_env(:exnews, :hn_api_base_url)
  @max_attempts 3

  @callback get(String.t()) :: {:ok, body :: map} | :error

  @spec get(url :: String.t(), attempts :: integer) ::
          {:ok, body :: map}
          | :error
  def get(url, attempts \\ 0) do
    url = "#{@base_url}#{url}"
    {:ok, %{body: body, status_code: status_code}} = HTTPoison.get(url)

    cond do
      status_code == 200 ->
        Jason.decode(body)

      attempts + 1 == @max_attempts ->
        Logger.info(
          "Giving up on #{url} after #{@max_attempts} attempts. Error code: #{status_code}"
        )

        :error

      true ->
        Logger.info(
          "Request against #{url} failed with status code #{status_code}. Trying again..."
        )

        :timer.sleep(250)
        get(url, attempts + 1)
    end
  end
end
