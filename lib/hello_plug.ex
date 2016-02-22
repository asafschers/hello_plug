defmodule HelloPlug do
  require Logger
  use Plug.Router
  use Timex

  plug Plug.Logger, log: :debug
  plug :match
  plug :dispatch

  post "/bang" do
    result = with :ok <- validate_headers(conn),
                  {:ok, body} <- extract_body(conn),
                  {:ok, json} <- extract_json(body),
                  :ok <- validate_created_at(json),
                  :ok <- validate_id(json),
                  :ok <- send_sqs_message(json)
             do
               :ok
             end
    case result do
      :ok -> send_resp(conn, 200, "")
      {:error, response} -> send_resp(conn, response.code, response.body)
      _ -> send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp validate_headers(conn) do
    case get_req_header(conn, "x-riskified-shop-domain") do
      [] ->
        Logger.error("Invalid header")
        error_response(400, "")
      _ ->
        :ok
    end
  end

  defp extract_body(conn) do
    case read_body(conn) do
      {:more, _, _} ->
        Logger.error("Body too large!")
        error_response(400, "")
      {:error, _} ->
        Logger.error("Error reading body!")
        error_response(500, "")
      {:ok, body, _} ->
        {:ok, body}
    end
  end

  defp extract_json(body) do
    case JSON.decode(body) do
      {:ok, parsed} -> {:ok, parsed}
      _ ->
        Logger.error("Error extracting json")
        error_response(400, "")
    end
  end

  defp validate_created_at(json) do
    case json["created_at"] do
      nil ->
        Logger.error("Missing created_at!")
        error_response(400, "")
      "" ->
        Logger.error("Empty created_at!")
        error_response(400, "")
      date ->
        case DateFormat.parse(date, "{ISO}") do
          {:ok, _} -> :ok
          _ ->
            Logger.error("Invalid date format!")
            error_response(400, "")
        end
    end
  end

  defp validate_id(json) do
    case json["id"] do
      nil ->
        Logger.error("Missing id!")
        error_response(400, "")
      "" ->
        Logger.error("Empty id")
        error_response(400, "")
      _ ->
        :ok
    end
  end

  def send_sqs_message(json) do
    case JSON.encode(json) do
      {:ok, encoded} ->
        res = try do
          :erlcloud_sqs.send_message(["botw_scratch"], [encoded])
        rescue
          e in ErlangError ->
            Logger.error(inspect(e))
            error_response(500, "")
        end
        case res do
          {:error, _} -> res
          _ -> :ok
        end
      _ ->
        Logger.error("Error encoding body")
        error_response(500, "")
    end
  end

  defp error_response(code, body) do
    {:error, %{code: code, body: body}}
  end
end
