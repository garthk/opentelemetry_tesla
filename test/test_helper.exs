{:ok, _} = Application.ensure_all_started(:opentelemetry_tesla)
{:ok, _} = Application.ensure_all_started(:mox)

Mox.defmock(MockAdapter, for: Tesla.Adapter)

:ets.new(OpenTelemetry.ExportedSpans, ~w[public bag named_table]a)
:otel_batch_processor.set_exporter(:otel_exporter_tab, OpenTelemetry.ExportedSpans)

ExUnit.start()
