defmodule ExNews.State do
  @moduledoc """

  """

  use GenServer

  @table_name :exnews_state
  @read_protection if(Mix.env() == :test, do: :public, else: :protected)

  @type story :: map

  @typep story_id :: integer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec lookup(page :: pos_integer, results_per_page :: pos_integer) ::
          [story]
  def lookup(page, results_per_page) do
    case :ets.lookup(@table_name, :items) do
      [] ->
        []

      [items: payload] ->
        range = ((page - 1) * results_per_page)..(page * results_per_page - 1)
        Enum.slice(payload, range)
    end
  end

  @spec single_lookup(story_id) ::
          story | nil
  def single_lookup(id) do
    case :ets.lookup(@table_name, :items) do
      [] ->
        []

      [items: payload] ->
        Enum.find(payload, fn post ->
          post["id"] == id
        end)
    end
  end

  @spec write([story]) ::
          [story]
  def write(stories) do
    GenServer.call(__MODULE__, {:write_items, stories})

    stories
  end

  def init(_) do
    :ets.new(@table_name, [:named_table, @read_protection, read_concurrency: true])

    {:ok, %{}}
  end

  def handle_call({:write_items, v}, _from, state) do
    :ets.insert(@table_name, {:items, v})

    {:reply, :ok, state}
  end
end
