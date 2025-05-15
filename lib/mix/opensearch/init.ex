defmodule AepfOpensearch.Init do
  @moduledoc "Seeds OpenSearch indices with correct mappings."

  @headers [{"Content-Type", "application/json"}]

  @indices %{
    "event_type" => %{
      mappings: %{
        properties: %{
          event_id: %{
            type: "text",
            fields: %{keyword: %{type: "keyword", ignore_above: 256}}
          },
          event_type: %{
            type: "text",
            fields: %{keyword: %{type: "keyword", ignore_above: 256}}
          },
          received_at: %{type: "date"},
          event_params: %{
            type: "nested",
            properties: %{
              key: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              label: %{type: "text"},
              type: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              required: %{type: "boolean"},
              default: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              reference_type: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              select_value_field: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              select_label_field: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              minLength: %{type: "integer"},
              maxLength: %{type: "integer"}
            }
          }
        }
      }
    },
    "event_stream" => %{
      mappings: %{
        properties: %{
          ack: %{type: "boolean"},
          body: %{
            properties: %{
              event_id: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              event_type: %{
                type: "text",
                fields: %{keyword: %{type: "keyword", ignore_above: 256}}
              },
              received_at: %{type: "date"},
              event_params: %{
                properties: %{
                  default: %{
                    type: "text",
                    fields: %{keyword: %{type: "keyword", ignore_above: 256}}
                  },
                  key: %{
                    type: "text",
                    fields: %{keyword: %{type: "keyword", ignore_above: 256}}
                  },
                  label: %{
                    type: "text",
                    fields: %{keyword: %{type: "keyword", ignore_above: 256}}
                  },
                  maxLength: %{type: "long"},
                  message: %{
                    type: "text",
                    fields: %{keyword: %{type: "keyword", ignore_above: 256}}
                  },
                  minLength: %{type: "long"},
                  required: %{type: "boolean"},
                  type: %{
                    type: "text",
                    fields: %{keyword: %{type: "keyword", ignore_above: 256}}
                  }
                }
              }
            }
          },
          event_id: %{type: "keyword"},
          event_type: %{type: "keyword"},
          received_at: %{type: "date"},
          subject: %{type: "keyword"}
        }
      }
    }
  }

  def seed_index do
    Enum.each(@indices, fn {index, body} ->
      url = "http://localhost:9200/#{index}"

      case Finch.build(:get, url, @headers) |> Finch.request(Aepf.Finch) do
        {:ok, %Finch.Response{status: 200}} ->
          IO.puts("✅ Index #{index} already exists, skipping.")

        {:ok, %Finch.Response{status: 404}} ->
          IO.puts("⏳ Creating index #{index}...")
          create_req = Finch.build(:put, url, @headers, Jason.encode!(body))

          case Finch.request(create_req, Aepf.Finch) do
            {:ok, %Finch.Response{status: 200}} ->
              IO.puts("✅ Index #{index} created successfully.")

            {:ok, %Finch.Response{status: status, body: body}} ->
              IO.puts("❌ Failed to create #{index} with status #{status}: #{body}")

            {:error, reason} ->
              IO.inspect(reason, label: "❌ Error creating index #{index}")
          end

        {:error, reason} ->
          IO.inspect(reason, label: "❌ Error checking index #{index}")
      end
    end)
  end
end
