# OpenTelemetry.Tesla

[![Build status badge](https://github.com/garthk/opentelemetry_tesla/workflows/Elixir%20CI/badge.svg)](https://github.com/garthk/opentelemetry_tesla/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/opentelemetry_tesla.svg)](https://hex.pm/packages/opentelemetry_tesla)

<!-- MDOC !-->

`opentelemetry_tesla` provides an [OpenTelemetry] integration for the [Tesla] HTTP client library.

[OpenTelemetry]: https://opentelemetry.io
[Tesla]: https://hex.pm/packages/tesla

## Installation

Add `opentelemetry`, `opentelemetry_api`, and `opentelemetry_tesla` to your `deps` in
`mix.exs`:

```elixir
{:opentelemetry, "~> 0.6.0"},
{:opentelemetry_api, "~> 0.6.0"},
{:opentelemetry_tesla, "~> 0.6.0-rc.1"},
```

In your Tesla client module, `plug` the telemetry middleware last. If the client is for a
particular peer service, name it wit the `peer_service` option. For example:

```elixir
defmodule MyApp.MyPeer.Client do
  use Tesla

  plug Tesla.Middleware.Headers, [{"user-agent", inspect(__MODULE__)}]
  plug Tesla.Middleware.Compression, format: "gzip"
  plug OpenTelemetry.Tesla.Middleware, peer_service: "my_peer"
end
```

If the client is for a peer service you trust with your propagation headers, set the `propagator`:

```elixir
defmodule MyApp.MyPeer.Client do
  use Tesla

  plug Tesla.Middleware.Headers, [{"user-agent", inspect(__MODULE__)}]
  plug Tesla.Middleware.Compression, format: "gzip"
  plug OpenTelemetry.Tesla.Middleware,
    peer_service: "my_peer",
    propagator: :otel_propagator_http_w3c
end
```

Disable propagation implicitly by leaving `propagator` unset, or explicitly by setting it to
`nil` or `false`. You can also use the default W3C propagator by setting it to `true`.

## Trace Span Attributes

`OpenTelemetry.Tesla` sends the following trace span attributes, following the [OpenTelemetry Trace
Semantic Conventions]:

[OpenTelemetry Trace Semantic Conventions]: https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions

|Attribute|Derived from|
|-|-|
|`"http.host"`|The `host` part of `url`|
|`"http.method"`|`method` via `URI.parse/1` and `String.upcase/1`|
|`"http.path"`|The `path` part of `url`; `""` if absent|
|`"http.request_content_length"`|`headings`; falls back to `IO.iodata_length/1`|
|`"http.response_content_length"`|`headings`; falls back to `IO.iodata_length/1`|
|`"http.scheme"`|The `scheme` part of `url`|
|`"http.status_code"`|`status`|
|`"http.target"`|The `path` and `query` parts of `url`|
|`"http.url"`|`url`|
|`"http.user_agent"`|`headings`|
|`"peer.service"`|The `peer_service` option|

In the table above `headings`, `method`, `status`, and `url` are members of
`t:Tesla.Env.t/0`. We parse `url` with `URI.parse/1` and reassemble it with `URI.to_string/1`.

<!-- MDOC !-->
