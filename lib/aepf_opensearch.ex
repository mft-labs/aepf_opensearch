defmodule AepfOpensearch do
  @moduledoc "Easy entry point: `data_layer AshOpenSearch.DataLayer`"
  alias AepfOpensearch.DataLayer

  def hello do
    :world
  end

  def data_layer do
    DataLayer
  end
end
