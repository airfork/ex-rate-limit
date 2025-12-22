defmodule Bucket.Bucket do
  @moduledoc """
  A module for a bucket resource.

  The bucket resource is responsible for storing the rate limit data.
  Access to the bucket is rate limited by the bucket resource.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, opts}
  end
end
