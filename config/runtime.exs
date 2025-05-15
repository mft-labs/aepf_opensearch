# config/runtime.exs
import Config

config :aepf_opensearch,
  opensearch_url: System.get_env("OPENSEARCH_URL") || "http://localhost:9200"
