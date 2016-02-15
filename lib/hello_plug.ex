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
    |> send_resp(200, "")
  end

  match _ do
    send_resp(conn, 404, "")
  end

  def validate_header(conn) do
    if get_req_header(conn, "x-riskified-shop-domain") == [] do
      send_resp(conn, 400, "")
      halt(conn)
    end
    conn
  end

  def validate_body(conn) do
    {_, body, _} = read_body(conn)
    {value, parsed_body} = JSON.decode(body)

    if value != :ok do
      send_resp(conn, 400, "")
      halt(conn)
    end

    id = parsed_body["id"]
    created_at = parsed_body["created_at"]

    if is_nil(created_at) || is_nil(id) do
      send_resp(conn, 400, "")
      halt(conn)
    end

    {value, _} = DateFormat.parse(created_at, "{ISO}")

    if value != :ok || String.length(id) == 0 do
      send_resp(conn, 400, "")
      halt(conn)
    end

    conn
  end

  def send_sqs_message(conn) do
    :erlcloud_sqs.send_message
  end
end

# TODO: push to sqs
# TODO: make code functional and nice
# TODO: deployment
