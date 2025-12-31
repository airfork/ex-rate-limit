defmodule RateLimit do
  @moduledoc """
  An OTP application for rate limiting access to a bucket resource.
  """

  use Application

  @impl true
  def start(_type, _args) do
    RateLimit.Supervisor.start_link([])
  end

  # === Public API ===

  # Create a new bucket
  # Calls the DynamicSupervisor to start a new bucket which
  # will look up the bucket in the Registry and start a new bucket if it doesn't exist
  def create(bucket, opts \\ []) do
    opts = Keyword.put(opts, :key, bucket)

    case DynamicSupervisor.start_child(RateLimit.BucketSupervisor, {RateLimit.Bucket, opts}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_exists}
      {:error, _reason} -> {:error, :unknown_error}
    end
  end

  # Check the status of a bucket
  # Looks up the bucket in the Registry and calls the handle_call :check on the bucket's GenServer to get the status of the bucket
  def check(bucket) do
    case Registry.lookup(RateLimit.Registry, bucket) do
      [{pid, _}] -> GenServer.call(pid, :check)
      [] -> {:invalid_key, key: bucket}
    end
  end

  # Put data into a bucket
  # Looks up the bucket in the Registry and calls the handle_call {:put, data} on the bucket's GenServer to put the data into the bucket
  def put(bucket, data \\ %{}) do
    case Registry.lookup(RateLimit.Registry, bucket) do
      [{pid, _}] -> GenServer.call(pid, {:put, data})
      [] -> {:invalid_key, key: bucket}
    end
  end

  # Get data from a bucket
  # Looks up the bucket in the Registry and calls the handle_call {:get, fields} on the bucket's GenServer to get the data from the bucket
  def get(bucket, fields \\ []) do
    case Registry.lookup(RateLimit.Registry, bucket) do
      [{pid, _}] -> GenServer.call(pid, {:get, fields})
      [] -> {:invalid_key, key: bucket}
    end
  end
end
