defmodule HelloPlug do
  require Logger
  use Plug.Router
  use Timex

  plug Plug.Logger, log: :debug
  plug :match
  plug :dispatch

  post "/bang" do
    conn
    |> validate_header
    |> validate_body
    |> send_sqs_message
    |> respond(conn)
  end

  match _ do
    send_resp(conn, 404, "")
  end

  def validate_header(conn) do
    if get_req_header(conn, "x-riskified-shop-domain") == [] do
      Logger.error("Invalid header")
      {:error, %{:code => 400, :body => ""}}
    else
      {:ok, conn}
    end
  end

  def validate_body(conn_data) do
    case conn_data do
      {:error, _} -> conn_data
      {:ok, conn} ->
        case read_body(conn) do
          {:more, _, _} ->
            {:error, %{:code => 400, :body => ""}}
          {:error, _} ->
            {:error, %{:code => 500, :body => ""}}
          {:ok, body, _} ->
            body
            |> extract_json
            |> validate_created_at
            |> validate_id
        end
    end
  end

  def send_sqs_message(json) do
    case json do
      {:error, _} -> json
      {:ok, data} ->
        case JSON.encode(data) do
          {:ok, res} ->
            res = try do
              :erlcloud_sqs.send_message(["botw_scratch"], [res])
            rescue
              e in ErlangError ->
                Logger.error(inspect(e))
                {:error, %{:code => 500, :body => ""}}
            end
            case res do
              {:error, _} -> res
              _ -> {:ok, json}
            end
          _ ->
            Logger.error("Error encoding body")
            {:error, %{:code => 500, :body => ""}}
        end
    end
  end

  defp extract_json(body) do
    case JSON.decode(body) do
      {:ok, parsed} -> {:ok, parsed}
      {_, _} ->
        Logger.error("Error extracting json")
        {:error, %{:code => 500, :body => ""}}
    end
  end

  defp validate_created_at(json) do
    case json do
      {:error, _} ->
        json
      {:ok, json_data} ->
        case json_data["created_at"] do
          nil ->
            Logger.error("Empty created_at")
            {:error, %{:code => 400, :body => ""}}
          "" ->
            Logger.info("Empty created_at")
            {:error, %{:code => 400, :body => ""}}
          date ->
            case DateFormat.parse(date, "{ISO}") do
              {:ok, _} -> json
              {_, _} ->
                Logger.error("Invalid date format")
                {:error, %{:code => 400, :body => ""}}
            end
        end
    end
  end

  defp validate_id(json) do
    case json do
      {:error, _} ->
        json
      {:ok, json_data} ->
        case json_data["id"] do
          nil ->
            Logger.error("Missing id")
            {:error, %{:code => 400, :body => ""}}
          "" ->
            Logger.error("Empty id")
            {:error, %{:code => 400, :body => ""}}
          _ -> json
        end
    end
  end

  defp respond(response, conn) do
    case response do
      {:ok, _} -> send_resp(conn, 200, "")
      {:error, resp} -> send_resp(conn, resp[:code], resp[:body])
    end
  end
end
# TODO: push to sqs
# TODO: make code functional and nice
# TODO: deployment
