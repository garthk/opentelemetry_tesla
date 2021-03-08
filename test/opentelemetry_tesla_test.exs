defmodule TestClient do
  use Tesla
  plug Tesla.Middleware.Headers, [{"user-agent", inspect(__MODULE__)}]
  plug Tesla.Middleware.Compression, format: "gzip"
  # PUT IT LAST:
  plug OpenTelemetry.Tesla.Middleware, peer_service: "peer"
  adapter MockAdapter
end

defmodule SpanCtx do
  require Record
  @fields Record.extract(:span_ctx, from_lib: "opentelemetry_api/include/opentelemetry.hrl")
  Record.defrecordp(:span_ctx, @fields)
  defstruct @fields
  def from(rec) when Record.is_record(rec, :span_ctx), do: struct!(__MODULE__, span_ctx(rec))
end

defmodule Span do
  require Record
  @fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecordp(:span, @fields)
  defstruct @fields
  def from(rec) when Record.is_record(rec, :span), do: struct!(__MODULE__, span(rec))
end

defmodule OpenTelemetry.TeslaTest do
  use ExUnit.Case, async: true

  import Mox, only: [set_mox_from_context: 1, verify_on_exit!: 1]

  alias OpenTelemetry.Tesla.Middleware
  alias Tesla.Env

  require OpenTelemetry.Tracer, as: Tracer

  setup :set_mox_from_context
  setup :verify_on_exit!
  setup :provide_test_span

  def provide_test_span(ctx) do
    test_name = Atom.to_string(ctx.test)

    # We can YOLO this because crash handling isn't necessary because it's a test:
    assert :undefined = Tracer.current_span_ctx()

    span_ctx =
      Tracer.start_span(:undefined, test_name, %{
        attributes: [
          {"code.line", ctx.line, "code.file", ctx.file, "code.namespace", inspect(ctx.module)}
        ]
      })

    on_exit(fn ->
      Tracer.set_current_span(span_ctx)
      Tracer.end_span()
    end)

    Tracer.set_current_span(span_ctx)

    %{trace_id: trace_id, span_id: span_id} = SpanCtx.from(span_ctx)
    [trace_id: trace_id, test_span_id: span_id]
  end

  test "integration test", %{trace_id: trace_id, test_span_id: test_span_id} do
    Mox.expect(MockAdapter, :call, fn
      %{method: :get, url: "https://example.com" <> _} = env, [] ->
        body = %{env: env, span_ctx: Tracer.current_span_ctx()}
        {:ok, %{env | status: 200, headers: [{"content-length", "23"}], body: body}}
    end)

    assert {:ok, %{status: 200, body: %{env: env, span_ctx: span_ctx}}} =
             TestClient.get("https://example.com/path", query: [k: "v"])

    assert %SpanCtx{trace_id: ^trace_id, span_id: span_id} = SpanCtx.from(span_ctx)
    assert span_id != test_span_id, "inner span not started"
    assert "00-" <> _ = Tesla.get_header(env, "traceparent")

    # Wait for the exporter. https://github.com/open-telemetry/opentelemetry-erlang/issues/218
    :timer.sleep(10)

    assert [
             %Span{
               attributes: attributes,
               kind: :client,
               name: "HTTP GET",
               parent_span_id: ^test_span_id,
               span_id: ^span_id,
               status: {:status, 0, "OK"},
               trace_id: ^trace_id
             }
           ] = gather_spans(trace_id)

    assert [
             {"http.host", "example.com"},
             {"http.method", "GET"},
             {"http.path", "/path"},
             {"http.response_content_length", 23},
             {"http.scheme", "https"},
             {"http.status_code", 200},
             {"http.target", "/path?k=v"},
             {"http.url", "https://example.com/path?k=v"},
             {"http.user_agent", "TestClient"},
             {"peer.service", "peer"}
           ] = Enum.sort(attributes)
  end

  describe "semantic HTTP request attribute corner cases" do
    test "empty path" do
      assert {"http.path", ""} =
               %Env{url: "https://example.com"}
               |> Middleware.request_attributes()
               |> List.keyfind("http.path", 0)
    end

    test "no content-length (in)" do
      body = [?1, "23", ["4"]]

      assert {"http.response_content_length", 4} =
               %Env{body: body}
               |> Middleware.response_attributes()
               |> List.keyfind("http.response_content_length", 0)
    end

    test "no content-length (out)" do
      body = [?1, "23", ["4"]]

      assert {"http.request_content_length", 4} =
               %Env{body: body}
               |> Middleware.request_attributes()
               |> List.keyfind("http.request_content_length", 0)
    end
  end

  defp gather_spans(trace_id) do
    OpenTelemetry.ExportedSpans
    |> :ets.tab2list()
    |> Enum.map(&Span.from/1)
    |> Enum.filter(&(&1.trace_id == trace_id))
    |> Enum.sort_by(& &1.start_time)
  end
end
