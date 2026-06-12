defmodule DiscourseApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DiscourseApp.Repo,
      DiscourseAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:discourse_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DiscourseApp.PubSub},
      {Task.Supervisor, name: DiscourseApp.AnalysisTaskSupervisor},
      # Start a worker by calling: DiscourseApp.Worker.start_link(arg)
      # {DiscourseApp.Worker, arg},
      # Start to serve requests, typically the last entry
      DiscourseAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DiscourseApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DiscourseAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
