defmodule RateLimit.Supervisor do
  @moduledoc """
  A supervisor for the registry and dynamic bucket supervisor
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Supervisor.init([
      # Registry - Tracks bucket_key -> PID mappings
      {Registry, keys: :unique, name: RateLimit.Registry},

      # DynamicSupervisor - Manages bucket GenServers on demand
      {DynamicSupervisor, name: RateLimit.BucketSupervisor, strategy: :one_for_one}
    ], strategy: :one_for_one)
  end
end
