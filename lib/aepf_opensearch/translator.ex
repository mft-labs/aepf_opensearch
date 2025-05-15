defmodule AepfOpensearch.Translator do
  @moduledoc """
  Translates Ash filter expressions and sort orders into OpenSearch DSL.
  """

  alias Ash.Query.{BooleanExpression, Operator}
  alias Ash.Query.Ref
  alias Ash.Query.Operator.{Eq, NotEq, IsNil}
  alias Ash.Query.Functions.{Like, ILike}
  alias Ash.Query.Argument

  alias Ash.Query.Operator.{
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual
  }

  alias Ash.Query.BooleanExpression
  require Logger
  alias Ash.Query.Function.In

  # Query builder
  def build_query(nil), do: %{"match_all" => %{}}

  def build_query(expr) do
    %{"bool" => %{"filter" => [translate(expr)]}}
  end

  # Sort builder
  def build_sort([]), do: []

  def build_sort(sort) when is_list(sort) do
    Enum.map(sort, fn {field, direction} ->
      field_str = to_string(field)

      # Use `.keyword` for text fields, fallback to base field if needed
      field_key =
        case direction do
          :asc -> "#{field_str}"
          :desc -> "#{field_str}"
        end

      %{field_key => %{"order" => to_string(direction)}}
    end)
  end

  def translate(%Eq{left: %Ref{attribute: attr}, right: value}) do
    field = keyword_field(attr)

    cond do
      is_struct(value, Regex) ->
        # Handle native Regex struct
        build_regexp(field, value.source, Regex.opts(value))

      is_binary(value) and String.match?(value, ~r/^~r\/.*\/[a-z]*$/) ->
        Logger.debug("Regex match found in value: #{inspect(value)}")

        case Regex.run(~r/^~r\/(.*)\/([a-z]*)$/, value) do
          [_, pattern, opts] ->
            flag = if String.contains?(opts, "i"), do: "i", else: nil
            Logger.debug("Compiled regex with flags: #{inspect(flag)}")
            build_regexp(keyword_field(attr), pattern, flag)

          _ ->
            raise "Invalid regex format: #{value}"
        end

      is_binary(value) and String.contains?(value, "%") ->
        Logger.debug("Wildcard match found in value: #{inspect(value)}")
        %{"wildcard" => %{keyword_field(attr) => String.replace(value, "%", "*")}}

      true ->
        # Logger.debug("Exact match found in value: #{inspect(value)}")
        %{"term" => %{keyword_field(attr) => value}}
    end
  end

  defp build_regexp(field, pattern, nil) do
    %{"regexp" => %{field => pattern}}
  end

  defp build_regexp(field, pattern, "i") do
    # Append `(?i)` for case-insensitive inline flag in OpenSearch
    # %{"regexp" => %{field => "(?i)" <> pattern}}
    %{
      "regexp" => %{
        field => %{
          "value" => pattern,
          "flags" => "ALL",
          "case_insensitive" => true
        }
      }
    }
  end

  # Inequality
  def translate(%NotEq{left: %Ref{attribute: attr}, right: value}) do
    %{"bool" => %{"must_not" => [%{"term" => %{keyword_field(attr) => value}}]}}
  end

  # IN operator
  def translate(%Ash.Query.Operator.In{
        left: %Ash.Query.Ref{attribute: attr},
        right: values
      }) do
    values = if is_struct(values, MapSet), do: MapSet.to_list(values), else: values
    %{"terms" => %{keyword_field(attr) => values}}
  end

  defp translate_range(attr, op, value) do
    %{"range" => %{keyword_field(attr) => %{op => value}}}
  end

  # Greater Than
  def translate(%GreaterThan{left: %Ref{attribute: attr}, right: value}),
    do: translate_range(attr, "gt", value)

  # Greater Than or Equal
  def translate(%GreaterThanOrEqual{left: %Ref{attribute: attr}, right: value}),
    do: translate_range(attr, "gte", value)

  # Less Than
  def translate(%LessThan{left: %Ref{attribute: attr}, right: value}),
    do: translate_range(attr, "lt", value)

  # Less Than or Equal
  def translate(%LessThanOrEqual{left: %Ref{attribute: attr}, right: value}),
    do: translate_range(attr, "lte", value)

  # is_nil(field)
  def translate(%Ash.Query.Operator.IsNil{left: %Ref{attribute: attr}}) do
    %{
      "bool" => %{
        "must_not" => [
          %{"exists" => %{"field" => to_string(attr.name)}}
        ]
      }
    }
  end

  # AND
  def translate(%Ash.Query.BooleanExpression{
        op: :and,
        left: left,
        right: right
      }) do
    IO.inspect(left, label: "🧩 Left of AND")
    IO.inspect(right, label: "🧩 Right of AND")

    %{"bool" => %{"must" => [translate(left), translate(right)]}}
  end

  # OR
  def translate(%BooleanExpression{op: :or, left: l, right: r}) do
    %{"bool" => %{"should" => [translate(l), translate(r)], "minimum_should_match" => 1}}
  end

  # NOT
  def translate(%Ash.Query.Not{expression: expr}) do
    IO.inspect(expr, label: "🧩 Inside Ash.Query.Not translator")

    %{
      "bool" => %{
        "must_not" => [translate(expr)]
      }
    }
  end

  def translate(other) do
    IO.inspect(other, label: "❌ Unsupported filter expression")
    raise "Unsupported filter expression: #{inspect(other)}"
  end

  def keyword_or_numeric_field(resource, field) do
    case Ash.Resource.Info.attribute(resource, field) do
      %{type: Ash.Type.String} -> "#{field}.keyword"
      _ -> to_string(field)
    end
  end

  # Helper to get .keyword for string attributes
  defp keyword_field(%{type: Ash.Type.UUID, name: name}), do: "#{name}.keyword"
  defp keyword_field(%{type: Ash.Type.String, name: name}), do: "#{name}.keyword"
  defp keyword_field(%{name: name}), do: to_string(name)
end
