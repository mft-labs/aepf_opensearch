defmodule AepfOpensearch.Query do
  defstruct resource: nil,
            api: nil,
            filter: nil,
            sort: [],
            limit: nil,
            offset: nil,
            context: %{},
            select: nil,
            aggregates: []
end
