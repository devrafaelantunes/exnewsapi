defmodule ExNews.FetcherTest do
  use ExUnit.Case
  import Mox

  alias ExNews.Test.{StateUtils}
  alias ExNews.{Fetcher}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    on_exit(fn ->
      StateUtils.wipe_state()
    end)

    unless Fetcher |> Process.whereis() |> is_nil do
      GenServer.stop(Fetcher, :normal)
    end

    # Ensure there's no other Fetcher instance running before the test starts
    nil = Fetcher |> Process.whereis()

    :ok
  end

  describe "fetcher" do
    test "fetches data on startup" do
      args = %{
        fetch_on_startup: true,
        interval: 999_999
      }

      ExNews.MockAPI
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1, 2]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1}}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/2.json"
        {:ok, %{"id" => 2}}
      end)

      {:ok, _} = start_supervised({Fetcher, args})

      # Wait for the data to be written to ETS
      :timer.sleep(20)

      assert [items: items] = StateUtils.get_all_items()
      assert Enum.sort(items) == [%{"id" => 1}, %{"id" => 2}]
    end

    test "fetches data periodically" do
      args = %{
        fetch_on_startup: false,
        interval: 100
      }

      ExNews.MockAPI
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1}}
      end)

      {:ok, _} = start_supervised({Fetcher, args})

      # Wait for the fetch timer and also for the data to be written to ETS
      :timer.sleep(120)

      assert [items: items] = StateUtils.get_all_items()
      assert Enum.sort(items) == [%{"id" => 1}]
    end

    test "timer resets and keeps fetching data over and over" do
      args = %{
        fetch_on_startup: false,
        interval: 100
      }

      ExNews.MockAPI
      # First interval
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1, "title" => "Title 1"}}
      end)
      # Second interval
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1, "title" => "Title 2"}}
      end)
      # Third interval
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1, "title" => "Title 3"}}
      end)

      {:ok, _} = start_supervised({Fetcher, args})

      # Result from first interval
      :timer.sleep(120)
      assert [items: items] = StateUtils.get_all_items()
      assert Enum.sort(items) == [%{"id" => 1, "title" => "Title 1"}]

      # Result from second interval
      :timer.sleep(120)
      assert [items: items] = StateUtils.get_all_items()
      assert Enum.sort(items) == [%{"id" => 1, "title" => "Title 2"}]

      # Result from third interval
      :timer.sleep(120)
      assert [items: items] = StateUtils.get_all_items()
      assert Enum.sort(items) == [%{"id" => 1, "title" => "Title 3"}]
    end

    test "timeout" do
      args = %{
        fetch_on_startup: false,
        interval: 100
      }

      ExNews.MockAPI
      # Simulating timeout on first interval
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        :error
      end)
      # Second interval works...
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      # ... but only on the `topstories` call
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        :error
      end)
      # Finally, third interval works fully
      |> expect(:get, fn url ->
        assert url =~ "/topstories.json"
        {:ok, [1]}
      end)
      |> expect(:get, fn url ->
        assert url =~ "/item/1.json"
        {:ok, %{"id" => 1}}
      end)

      {:ok, _} = start_supervised({Fetcher, args})

      # Nothing got stored on first interval (req. failed on `topstories`)
      :timer.sleep(120)
      assert [] == StateUtils.get_all_items()

      # Nothing got stored on second interval (req. failed on the only item)
      :timer.sleep(120)
      assert [items: []] == StateUtils.get_all_items()

      # Item got stored on the third interval
      :timer.sleep(120)
      assert [items: items] = StateUtils.get_all_items()
      assert items == [%{"id" => 1}]
    end
  end

  test "partial failure" do
    args = %{
      fetch_on_startup: true,
      interval: 999_999
    }

    ExNews.MockAPI
    # Request for item 2 will timeout, but items 1 and 3 will succeed
    |> expect(:get, fn url ->
      assert url =~ "/topstories.json"
      {:ok, [1, 2, 3]}
    end)
    |> expect(:get, fn url ->
      assert url =~ "/item/1.json"
      {:ok, %{"id" => 1}}
    end)
    |> expect(:get, fn url ->
      assert url =~ "/item/2.json"
      :error
    end)
    |> expect(:get, fn url ->
      assert url =~ "/item/3.json"
      {:ok, %{"id" => 3}}
    end)

    {:ok, _} = start_supervised({Fetcher, args})

    :timer.sleep(100)

    assert [items: items] = StateUtils.get_all_items()
    assert Enum.sort(items) == [%{"id" => 1}, %{"id" => 3}]
  end

  # TODO: test that new stories get broadcasted to connected WebSockets
  # This could be achieved by creating our own WS GenServer and making sure it receives a message
  # from the fetcher in the format of {:push, [State.story]}
end
