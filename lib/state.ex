defmodule ExNews.State do
  @moduledoc """
    ## Overview

    The ExNews.State module works by using ETS to store the stories.
    It can lookup stories based on its id and display pages based on 
    the desired results per page.

    ## Design decisions

    I chose to use ETS over a GenServer to prevent bottlenecks from happening. 
    Differently from the GenServer, ETS can write and read the state concurrently.

    ## Resiliency 

    If the HN API is down, the state will work as a cache until a new successful request is made to
    the HN API. The state won't rewrite itself if the request is not successful.
  """

  use GenServer

  # Sets the ETS's table name and protection status
  @table_name :exnews_state
  # Protected means that the ETS will only be avaliable for the process itself
  @read_protection if(Mix.env() == :test, do: :public, else: :protected)

  @type story :: map

  @typep story_id :: integer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
    Lookup the stories based on a range that is generated by the page number and 
    amount of results per page
  """
  @spec lookup(page :: pos_integer, results_per_page :: pos_integer) ::
          [story]
  def lookup(page, results_per_page) do
    # Make sure that the table contains the stories list
    case :ets.lookup(@table_name, :items) do
      [] ->
        []

      [items: payload] ->
        # Calculate the range
        range = ((page - 1) * results_per_page)..(page * results_per_page - 1)
        # Slice the stories list based on the range
        Enum.slice(payload, range)
    end
  end

  @doc """
    Lookup a single story based on its id
  """
  @spec single_lookup(story_id) ::
          story | nil
  def single_lookup(id) do
    case :ets.lookup(@table_name, :items) do
      [] ->
        []

      [items: payload] ->
        # Find the story inside of the Top 50 list based on its id
        Enum.find(payload, fn post ->
          post["id"] == id
        end)
    end
  end

  @doc """
    Calls the module Genserver to write the stories in the ETS table
  """
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
