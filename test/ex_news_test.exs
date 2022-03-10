defmodule ExNewsTest do
  use ExUnit.Case
  doctest ExNews

  test "greets the world" do
    assert ExNews.hello() == :world
  end
end
