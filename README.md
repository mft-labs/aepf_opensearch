# AepfOpensearch

`AepfOpensearch` is an Elixir library that provides an OpenSearch data layer integration for the Ash Framework. It enables seamless interaction between Ash resources and OpenSearch, facilitating efficient data querying and indexing.

## Features

- **Ash Data Layer Integration**: Implements the `Ash.DataLayer` behavior to connect Ash resources with OpenSearch.
- **Custom Query Translator**: Translates Ash queries into OpenSearch DSL for efficient search operations.
- **OpenSearch Client**: Handles HTTP interactions with the OpenSearch server.
- **Seeder Utility**: Provides tools to seed data into OpenSearch indices.

## Installation

Add `aepf_opensearch` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aepf_opensearch, "~> 0.1.0"}
  ]
end
```

Then, run:

```bash
mix deps.get
```

## Configuration

Configure the OpenSearch client in your application's config files:

```elixir
config :aepf_opensearch, AepfOpensearch.Client,
  base_url: "http://localhost:9200",
  json_library: Jason
```

## Usage

To use `AepfOpensearch` as the data layer for an Ash resource:

```elixir
defmodule MyApp.BlogPost do
  use Ash.Resource,
    data_layer: AepfOpensearch.DataLayer

  data_layer do
    config :index, "blog_posts"
  end

  # Define your attributes and actions here
end
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/aepf_opensearch](https://hexdocs.pm/aepf_opensearch).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open issues or submit pull requests for any enhancements or bug fixes.
