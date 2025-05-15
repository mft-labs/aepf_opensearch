defmodule AepfOpensearch.Client do
  @moduledoc false

  @http_client Application.compile_env(:aepf_opensearch, :http_client, Aepf.Finch)

  require Logger
  import Ash.Filter
  # alias AepfOpensearch.Query
  alias AepfOpensearch.Translator
  alias Ash.Query

  defp index_for(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> then(&"#{&1}")
  end

  defp url_for(resource, path \\ "") do
    index = index_for(resource)
    "http://localhost:9200/#{index}#{path}"
  end

  def insert(resource, data) do
    data = Map.new(data)
    # id = Map.get(data, :id) || UUID.uuid4()
    pk_field = Ash.Resource.Info.primary_key(resource) |> List.first()
    id = Map.get(data, pk_field) || UUID.uuid4()
    # data = Map.put(data, :id, id)
    data = Map.put(data, pk_field, id)
    json = Jason.encode!(data)
    # url = "#{@url}/_doc/#{id}"
    # url = url_for(resource, "/_doc/#{id}?refresh=wait_for")
    url = url_for(resource, "/_doc/#{id}")

    case Finch.build(:put, url, headers(), json) |> Finch.request(@http_client) do
      {:ok, %{status: 201}} ->
        # You must return a MAP or STRUCT (not a tuple or keyword)
        {:ok, struct(resource, data)}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  def update(resource, id, changes) do
    changes = Map.new(changes)
    json = Jason.encode!(%{doc: changes})
    # url = "#{@url}/_update/#{id}"
    # url = url_for(resource, "/_update/#{id}?refresh=wait_for")
    url = url_for(resource, "/_update/#{id}")

    case Finch.build(:post, url, headers(), json) |> Finch.request(@http_client) do
      {:ok, %{status: 200}} ->
        full = Map.put(changes, :id, id)
        {:ok, struct(resource, full)}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  def delete(resource, id) do
    # url = "#{@url}/_doc/#{id}"
    # url = url_for(resource, "/_doc/#{id}?refresh=wait_for")
    url = url_for(resource, "/_doc/#{id}")

    case Finch.build(:delete, url, headers()) |> Finch.request(@http_client) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  def query(%AepfOpensearch.Query{
        resource: resource,
        filter: %Ash.Filter{expression: expr},
        sort: sort,
        limit: limit,
        offset: offset
      }) do
    # IO.inspect(expr, label: "✅ Final AST to be translated")

    query = %{
      "query" => Translator.translate(expr),
      "sort" => Translator.build_sort(sort),
      "size" => limit || 100,
      "from" => offset || 0
    }

    do_search(resource, query)
  end

  def query(%AepfOpensearch.Query{
        resource: resource,
        filter: nil,
        sort: sort,
        limit: limit,
        offset: offset
      }) do
    query = %{
      "query" => %{"match_all" => %{}},
      "sort" => Translator.build_sort(sort),
      "size" => limit || 100,
      "from" => offset || 0
    }

    do_search(resource, query)
  end

  defp do_search(resource, query) do
    body = Jason.encode!(query)
    # url = "#{@url}/_search"
    url = url_for(resource, "/_search")
    # IO.inspect(url, label: "🔍 OpenSearch URL")
    # IO.inspect(body, label: "🔍 OpenSearch Body")

    case Finch.build(:post, url, headers(), body) |> Finch.request(@http_client) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, %{"hits" => %{"hits" => hits}}} <- Jason.decode(body) do
          results =
            Enum.map(hits, fn %{"_source" => source, "_id" => id} ->
              data = Map.put(source, "id", id)
              struct(resource, to_atom_keys(data))
            end)

          {:ok, results}
        end

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def aggregate(%Ash.Query{} = query, aggregates, resource) do
    open_query = %AepfOpensearch.Query{
      resource: resource,
      filter: query.filter,
      sort: query.sort || [],
      limit: query.limit,
      offset: query.offset,
      select: query.select,
      context: query.context || %{},
      api: Map.get(query, :api)
    }

    aggregate(open_query, aggregates, resource)
  end

  def aggregate(%AepfOpensearch.Query{} = query, aggregations, resource) do
    filter_expr =
      case query.filter do
        %Ash.Filter{expression: expr} when not is_nil(expr) ->
          %{"query" => Translator.translate(expr)}

        _ ->
          %{"query" => %{"match_all" => %{}}}
      end

    aggs =
      for {type, field} <- aggregations, into: %{} do
        field_str = Translator.keyword_or_numeric_field(resource, field)

        es_agg_type =
          case type do
            :count -> "value_count"
            :sum -> "sum"
            :avg -> "avg"
            :min -> "min"
            :max -> "max"
            _ -> raise "Unsupported aggregation type: #{inspect(type)}"
          end

        {Atom.to_string(type),
         %{
           es_agg_type => %{
             "field" => field_str
           }
         }}
      end

    body = Jason.encode!(Map.merge(filter_expr, %{"aggs" => aggs}))
    # url = "#{@url}/_search?size=0"
    url = url_for(resource, "/_search?size=0")
    IO.inspect(url, label: "🔍 OpenSearch Aggregation URL")

    case Finch.build(:post, url, headers(), body) |> Finch.request(@http_client) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, %{"aggregations" => result}} <- Jason.decode(body) do
          parsed =
            result
            |> Enum.map(fn {agg_name, %{"value" => val}} -> {String.to_atom(agg_name), val} end)
            |> Enum.into(%{})

          {:ok, parsed}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp keyword_field(field) when is_atom(field), do: "#{field}.keyword"
  # defp keyword_field(field) when is_binary(field), do: "#{field}.keyword"

  def count(resource, %Ash.Query{filter: filter}, field) do
    es_query = %{
      "query" => AepfOpensearch.Translator.build_query(filter),
      "track_total_hits" => true,
      "size" => 0,
      "aggs" => %{
        "total_count" => %{
          "value_count" => %{
            # "field" => to_string(field)
            "field" => field_to_keyword(field)
          }
        }
      }
    }

    body = Jason.encode!(es_query)
    # url = "#{@url}/_search"
    url = url_for(resource, "/_search?size=0")
    IO.inspect(url, label: "🔍 OpenSearch Count URL")

    case Finch.build(:post, url, headers(), body) |> Finch.request(@http_client) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"aggregations" => %{"total_count" => %{"value" => value}}}} ->
            {:ok, trunc(value)}

          other ->
            {:error, {:unexpected_response, other}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp field_to_keyword(field) when is_atom(field), do: "#{field}.keyword"

  defp to_atom_keys(map) do
    for {k, v} <- map, into: %{} do
      {String.to_atom(k), v}
    end
  end

  defp headers do
    [{"Content-Type", "application/json"}]
  end
end
