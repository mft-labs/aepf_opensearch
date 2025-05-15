defmodule AepfOpensearch.DataLayer do
  @moduledoc false
  @behaviour Ash.DataLayer
  @behaviour Ash.DataLayer.Filter

  alias AepfOpensearch.Client
  alias AepfOpensearch.Query
  alias Ash.Filter
  require Logger

  @impl true
  def supports_filter_expr?(%Ash.Query.Operator.GreaterThan{}), do: true
  def supports_filter_expr?(%Ash.Query.Operator.GreaterThanOrEqual{}), do: true
  def supports_filter_expr?(%Ash.Query.Operator.LessThan{}), do: true
  def supports_filter_expr?(%Ash.Query.Operator.LessThanOrEqual{}), do: true
  def supports_filter_expr?(_), do: false

  @impl true
  def resource_to_query(resource, _domain) do
    %Query{
      resource: resource,
      api: nil,
      filter: nil,
      sort: [],
      limit: nil,
      offset: nil,
      context: %{}
    }
  end

  @impl true
  def query(resource, ash_query, _opts) do
    %Query{
      resource: resource,
      api: ash_query.api,
      filter: ash_query.filter,
      sort: ash_query.sort || [],
      limit: ash_query.limit,
      offset: ash_query.offset,
      context: ash_query.context || %{}
    }
  end

  @impl true
  def run_query(%Query{} = query, _resource) do
    # IO.inspect(query, label: "🚀 run_query received")
    Client.query(query)
  end

  @impl true
  def filter(%Query{} = query, %Filter{} = filter, _resource) do
    {:ok, %{query | filter: filter}}
  end

  @impl true
  def sort(%Query{} = query, sort, _resource) do
    {:ok, %{query | sort: sort}}
  end

  @impl true
  def limit(%Query{} = query, limit, _resource) do
    {:ok, %{query | limit: limit}}
  end

  @impl true
  def offset(%Query{} = query, offset, _resource) do
    {:ok, %{query | offset: offset}}
  end

  @impl true
  def select(%Query{} = query, select, _resource) do
    {:ok, %{query | select: select}}
  end

  @impl true
  def aggregate(%Query{} = query, aggregates, resource) do
    Client.aggregate(query, aggregates, resource)
  end

  @impl true
  def can?(_, {:aggregate, _}), do: true

  @impl true
  def run_aggregate(
        %Ash.Query{aggregates: [%{kind: :count, name: name, field: field}]} = query,
        resource
      ) do
    with {:ok, count} <- Client.count(resource, query, field) do
      {:ok, %{name => count}}
    end
  end

  @impl true
  def can?(_, action)
      when action in [
             :read,
             :create,
             :update,
             :destroy,
             :filter,
             :boolean_filter,
             :nested_expressions,
             :sort,
             :limit,
             :offset,
             :select
           ],
      do: true

  @impl true
  def can?(_, {:filter_expr, _}), do: true

  @impl true
  def can?(_, {:sort, _field}), do: true

  @impl true
  def can?(_, {:aggregate, {:count, _field}}), do: true

  # def can?(_, {:aggregate, {_agg_type, _field}}), do: true
  @impl true
  def can?(_, {:aggregate, :count}), do: true
  def can?(_, {:aggregate, :sum}), do: true
  def can?(_, {:aggregate, :avg}), do: true
  def can?(_, {:aggregate, :min}), do: true
  def can?(_, {:aggregate, :max}), do: true
  @impl true
  def can?(_, _), do: false

  @impl true
  def create(resource, changeset) do
    if changeset.valid? do
      Client.insert(resource, changeset.attributes)
    else
      {:error, changeset.errors}
    end
  end

  @impl true
  def update(resource, changeset) do
    if changeset.valid? do
      # %{id: id} = changeset.data
      [pk_field] = Ash.Resource.Info.primary_key(resource)
      id = Map.get(changeset.data, pk_field)
      Logger.debug("Updating resource with ID: #{id}")
      Client.update(resource, id, changeset.attributes)
    else
      {:error, changeset.errors}
    end
  end

  @impl true
  def destroy(resource, %{data: %{id: id}}) do
    Client.delete(resource, id)
  end

  def schema(_), do: %{}
end
