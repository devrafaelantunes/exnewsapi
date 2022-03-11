defmodule ExNews.StateTest do
  use ExUnit.Case

  alias ExNews.Test.{StateUtils}
  alias ExNews.{State}

  setup do
    on_exit(fn ->
      StateUtils.wipe_state()
    end)

    :ok
  end

  describe "write/1" do
    test "it stores the entries in the ETS table" do
      assert [] == StateUtils.get_all_items()

      entries = [
        %{"id" => 1},
        %{"id" => 2}
      ]

      State.write(entries)

      assert [items: result] = StateUtils.get_all_items()
      assert Enum.sort(result) == Enum.sort(entries)
    end
  end

  describe "single_lookup/1" do
    test "returns the entry when it exists" do
      assert [] == StateUtils.get_all_items()

      State.write([%{"id" => 1}])
      assert %{"id" => 1} == State.single_lookup(1)
    end

    test "returns nil when entry does not exist" do
      assert [] == StateUtils.get_all_items()

      State.write([%{"id" => 1}])
      assert nil == State.single_lookup(2)
    end
  end
end
