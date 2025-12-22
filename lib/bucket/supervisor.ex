defmodule Bucket.Supervisor do
  @moduledoc """
  A supervisor for the bucket resources.

  The supervisor is responsible for starting and stopping the bucket resources.
  """

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_child(opts) do
    DynamicSupervisor.start_child(__MODULE__, {Bucket.Bucket, opts})
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
