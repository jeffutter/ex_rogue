defmodule ExRogueWeb.PageController do
  use ExRogueWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
