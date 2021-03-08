use Mix.Config

scheduled_delay_ms = if Mix.env() == :test, do: 1, else: 10_000

# You can also supply opentelemetry resources using environment variables, eg.:
# OTEL_RESOURCE_ATTRIBUTES=service.name=name,service.namespace=namespace

config :opentelemetry, :resource,
  service: [
    name: "service-name",
    namespace: "service-namespace"
  ]

config :opentelemetry,
  tracer: :otel_tracer_default,
  processors: [otel_batch_processor: %{scheduled_delay_ms: scheduled_delay_ms}]
