defmodule OpenTelemetry.Tesla do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)
end

defmodule OpenTelemetry.Tesla.Middleware do
  @moduledoc """
  Tesla middleware for generating spans for outgoing requests.
  """

  @behaviour Tesla.Middleware

  alias Tesla.Env

  require OpenTelemetry.Tracer, as: Tracer
  require :otel_propagator, as: Propagator

  def call(%Env{} = env, next, opts) do
    {peer_service, opts} = Keyword.pop(opts, :peer_service, nil)
    for {k, _} <- opts, do: raise(ArgumentError, "no such option: #{k}")

    Tracer.with_span "HTTP #{upcase_method(env.method)}", %{
      attributes: env |> request_attributes(peer_service) |> safe_attrs(),
      kind: :client
    } do
      headers = Propagator.text_map_inject([])

      case Tesla.run(Tesla.put_headers(env, headers), next) do
        {:ok, env} ->
          env |> response_attributes() |> safe_attrs() |> Tracer.set_attributes()
          env |> response_status() |> Tracer.set_status()
          {:ok, env}

        {:error, reason} ->
          reason |> error_status() |> Tracer.set_status()
          {:error, reason}
      end
    end
  end

  defp response_status(%Env{status: n}) when is_integer(n) and n >= 400,
    do: {:status, 2, "status_code=#{n}"}

  defp response_status(%Env{status: n}) when is_integer(n) and n >= 200,
    do: {:status, 0, "OK"}

  defp response_status(_), do: :undefined

  defp error_status(_), do: {:status, 2, "an error occurred"}

  @doc false
  def request_attributes(env, peer_service \\ nil) do
    uri = URI.parse(env.url)
    query = URI.encode_query(env.query)

    [
      # https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/http.md#common-attributes
      # https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/http.md#http-client
      {"http.host", uri.host},
      {"peer.service", peer_service},
      {"http.method", upcase_method(env.method)},
      {"http.path", uri.path || ""},
      {"http.target", URI.to_string(%URI{path: uri.path, query: query})},
      {"http.url", URI.to_string(%{uri | query: query})},
      {"http.scheme", uri.scheme},
      {"http.user_agent", Tesla.get_header(env, "user-agent")},
      {"http.request_content_length", safe_content_length(env)}
    ]
  end

  @doc false
  def response_attributes(env) do
    [
      {"http.status_code", env.status},
      {"http.response_content_length", safe_content_length(env)}
    ]
  end

  @methods for atom <- ~w[delete get head options patch post put trace]a,
               into: %{},
               do: {atom, atom |> Atom.to_string() |> String.upcase()}

  defp upcase_method(atom), do: @methods[atom] || atom |> Atom.to_string() |> String.upcase()

  defp safe_attrs(attrs), do: Enum.filter(attrs, fn {_, v} -> not is_nil(v) end)

  defp safe_content_length(env) do
    safe_int_header(env, "content-length") || IO.iodata_length(env.body)
  rescue
    ArgumentError -> nil
  end

  defp safe_int_header(env, key), do: env |> Tesla.get_header(key) |> safe_int()

  @dialyzer {:nowarn_function, safe_int: 1}

  defp safe_int(nil), do: nil

  defp safe_int(n) when is_integer(n), do: n

  defp safe_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
