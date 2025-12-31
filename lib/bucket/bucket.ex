defmodule RateLimit.Bucket do
  @moduledoc """
  A module for a bucket resource.

  The bucket resource is responsible for storing the rate limit data.
  Access to the bucket is rate limited by the bucket resource.
  """

  use GenServer

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient  # <-- Only restart on abnormal exit, not normal exit
    }
  end

  def start_link(opts) do
    bucket_key = Keyword.fetch!(opts, :key)

    # The :via tuple tells GenServer to register with the registry
    GenServer.start_link(__MODULE__, opts, name: via_tuple(bucket_key))
  end

  defp via_tuple(bucket_key) do
    {:via, Registry, {RateLimit.Registry, bucket_key}}
  end

  def init(opts) do
    # Extract passed in data, with defaults

    state = %{
      max_requests: Keyword.get(opts, :max_requests, 5),
      time_till_refresh: Keyword.get(opts, :time_till_refresh, 30000),
      used: 0,
      data: %{},
      last_refreshed_at: System.monotonic_time(:millisecond),
      idle_timeout: Keyword.get(opts, :idle_timeout, 60_000)
    }

    {:ok, state, state.idle_timeout}
  end

  # Check the bucket's status, does not consume a request
  # Returns {:ok, %{max_requests: integer, used: integer, time_till_refresh: integer}} if the bucket has capacity
  # Returns {:deny, retry_after_ms: integer} if the bucket is out of capacity
  # Will refresh the bucket if needed
  def handle_call(:check, _from, state) do
    new_state = refresh_if_needed(state)

    if new_state.used < new_state.max_requests do
      {:reply,
       {:ok,
        %{
          max_requests: new_state.max_requests,
          used: new_state.used,
          time_till_refresh:
            time_till_refresh(new_state.last_refreshed_at, new_state.time_till_refresh)
        }}, new_state, new_state.idle_timeout}
    else
      {:reply,
       {:deny,
        retry_after_ms:
          time_till_refresh(new_state.last_refreshed_at, new_state.time_till_refresh)}, new_state,
       new_state.idle_timeout}
    end
  end

  # Put data into the bucket, consumes one request
  # Returns {:ok} if the bucket has capacity
  # Returns {:deny, retry_after_ms: integer} if the bucket is out of capacity
  # Will refresh the bucket if needed
  def handle_call({:put, data}, _from, state) do
    new_state = refresh_if_needed(state)
    requests = new_state.used + 1

    if requests > new_state.max_requests do
      {:reply,
       {:deny,
        retry_after_ms:
          time_till_refresh(new_state.last_refreshed_at, new_state.time_till_refresh)}, new_state,
       new_state.idle_timeout}
    else
      new_state = %{new_state | used: requests, data: Map.merge(new_state.data, data)}
      {:reply, {:ok}, new_state, new_state.idle_timeout}
    end
  end

  # Get data from the bucket, consumes one request
  # Returns {:ok, state.data} if the bucket has capacity and no fields are provided
  # Returns {:ok, Map.take(state.data, fields)} if the bucket has capacity and fields are provided
  # Returns {:deny, retry_after_ms: integer} if the bucket is out of capacity
  # Will refresh the bucket if needed
  def handle_call({:get, fields}, _from, state) do
    new_state = refresh_if_needed(state)
    requests = new_state.used + 1

    if requests > new_state.max_requests do
      {:reply,
       {:deny,
        retry_after_ms:
          time_till_refresh(new_state.last_refreshed_at, new_state.time_till_refresh)}, new_state,
       new_state.idle_timeout}
    else
      new_state = %{new_state | used: requests}

      output =
        case fields do
          [] -> new_state.data
          _ -> Map.take(new_state.data, fields)
        end

      {:reply, {:ok, output}, new_state, new_state.idle_timeout}
    end
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  # Calculate the time until the bucket needs to be refreshed
  defp time_till_refresh(last_refreshed_at, time_till_refresh) do
    time_till_refresh - (System.monotonic_time(:millisecond) - last_refreshed_at)
  end

  # Update bucket's used and last_refreshed_at if needed
  defp refresh_if_needed(state) do
    if time_till_refresh(state.last_refreshed_at, state.time_till_refresh) <= 0 do
      %{state | used: 0, last_refreshed_at: System.monotonic_time(:millisecond)}
    else
      state
    end
  end
end
