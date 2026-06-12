defmodule DiscourseApp.Repo do
  use Ecto.Repo,
    otp_app: :discourse_app,
    adapter: Ecto.Adapters.SQLite3
end
