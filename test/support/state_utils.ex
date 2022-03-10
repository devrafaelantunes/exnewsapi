defmodule ExNews.Test.StateUtils do
  @table_name :exnews_state

  def wipe_state do
    :ets.delete_all_objects(@table_name)
  end

  def get_all_items do
    :ets.lookup(@table_name, :items)
  end
end
