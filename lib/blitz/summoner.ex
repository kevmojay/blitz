defmodule Blitz.Summoner do
  use GenServer, restart: :temporary
  alias RiotAPI
  @check_milliseconds 60000
  @monitor_expires_seconds 3600

  def init([puuid, summoner_name, region, parent_pid]) do
    now = DateTime.utc_now()
    schedule(:expiration, DateTime.add(now, @monitor_expires_seconds, :second))
    schedule(:check, @check_milliseconds)
    {:ok,
     %{
       puuid: puuid,
       summoner_name: summoner_name,
       last_game: DateTime.to_unix(DateTime.utc_now()),
       region: region,
       parent_pid: parent_pid
     }}
  end

  def child_spec(args_opts) do
    %{id: hd(args_opts), start: {__MODULE__, :start_link, [args_opts]}}
  end

  def start_link([puuid, summoner_name, region, parent_pid]) do
    GenServer.start_link(
      __MODULE__,
      [puuid, summoner_name, region, parent_pid]
    )
  end

  def handle_info(:check, state) do
    case Blitz.RiotAPI.get_newest_match(state.puuid, state.region, state.last_game) do
      nil ->
        schedule(:check, @check_milliseconds)
        {:noreply, state}

      match ->
        IO.puts("Summoner #{state.summoner_name} completed match #{match}")

        schedule(:check, @check_milliseconds)
        {:noreply, %{state | last_game: DateTime.to_unix(DateTime.utc_now())}}
    end
  end

  def handle_info(:shutdown, _) do
    exit(:normal)
  end

  defp schedule(:check, milliseconds) do
    Process.send_after(self(), :check, milliseconds)
  end

  defp schedule(:expiration, expiration_date_time) do
    milliseconds = DateTime.diff(expiration_date_time, DateTime.utc_now(), :millisecond)
    Process.send_after(self(), :shutdown, milliseconds)
  end
end
