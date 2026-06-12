defmodule DiscourseAppWeb.PageController do
  use DiscourseAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
