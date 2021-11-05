defmodule Blitz.RiotAPI do
  alias Hammer
  @expected_summoner_fields ~w(
    puuid name
  )
  @regions [
    americas: "br1",
    europe: "eun1",
    europe: "euw1",
    asia: "jp1",
    asia: "kr",
    americas: "la1",
    americas: "la2",
    americas: "na1",
    americas: "oc1",
    europe: "tr1",
    europe: "ru"
  ]
  @scale_ms_second 1000
  @limit_second 15
  @scale_ms_minute 10_000
  @limit_minute 10
  @match_count 5

  def wait_for_free_buckets() do
    {:ok, {_, count_remaining_second, _, _, _}} =
      Hammer.inspect_bucket("RiotAPISecond", @scale_ms_second, @limit_second)

    {:ok, {_, count_remaining_minute, _, _, _}} =
      Hammer.inspect_bucket("RiotAPIMinute", @scale_ms_minute, @limit_minute)

    cond do
      count_remaining_second == 0 || count_remaining_minute == 0 ->
        :timer.sleep(1000)
        wait_for_free_buckets()

      true ->
        true
    end
  end

  @doc """
    The Riot API limits for personal keys are 20 requests per second
    and 100 requests every 2 minutes. This will help maintain those limits.
  """
  def combine_bucket_check() do
    case Hammer.check_rate("RiotAPISecond", @scale_ms_second, @limit_second) do
      {:allow, _count} ->
        Hammer.check_rate("RiotAPIMinute", @scale_ms_minute, @limit_minute)

      {:deny, limit} ->
        {:deny, limit}
    end
  end

  def riot_api_key do
    Application.get_env(:blitz, Blitz)[:riot_api_key]
  end

  def summoner_by_name_url(region, summoner_name) do
    host = api_host(region)
    "#{host}/lol/summoner/v4/summoners/by-name/#{summoner_name}?api_key=#{riot_api_key()}"
  end

  def recent_matches_by_puuid_url(region, puuid, start_time, count) do
    host = region_host(region)

    "#{host}/lol/match/v5/matches/by-puuid/#{puuid}/ids?startTime=#{start_time}&start=0&count=#{count}&api_key=#{
      riot_api_key()
    }"
  end

  def match_by_id_url(region, match_id) do
    host = region_host(region)
    "#{host}/lol/match/v5/matches/#{match_id}?api_key=#{riot_api_key()}"
  end

  def fetch_summoner!(summoner_name, region) do
    case combine_bucket_check() do
      {:allow, _count} ->
        region
        |> summoner_by_name_url(summoner_name)
        |> HTTPoison.get!()
        |> Map.get(:body)
        |> Poison.decode!()
        |> Map.take(@expected_summoner_fields)

      {:deny, _limit} ->
        wait_for_free_buckets()
        fetch_summoner!(summoner_name, region)
    end
  end

  def fetch_recent_match_ids!(puuid, region, start_time \\ "", count \\ @match_count) do
    case combine_bucket_check() do
      {:allow, _count} ->
        region
        |> recent_matches_by_puuid_url(puuid, start_time, count)
        |> HTTPoison.get!()
        |> Map.get(:body)
        |> Poison.decode!()

      {:deny, _limit} ->
        wait_for_free_buckets()
        fetch_recent_match_ids!(puuid, region, start_time, count)
    end
  end

  def fetch_match_data!(match_id, region) do
    case combine_bucket_check() do
      {:allow, _count} ->
        region
        |> match_by_id_url(match_id)
        |> HTTPoison.get!()
        |> Map.get(:body)
        |> Poison.decode!()

      {:deny, _limit} ->
        wait_for_free_buckets()
        fetch_match_data!(match_id, region)
    end
  end

  def api_host(platform) do
    "https://#{platform}.api.riotgames.com"
  end

  def region_host(region) do
    @regions
    |> Enum.find(fn {_, platform} -> platform == region end)
    |> elem(0)
    |> Atom.to_string()
    |> api_host()
  end

  def valid_region?(region) do
    Enum.any?(@regions, fn {_, platform} -> platform == region end)
  end

  def get_list_of_participant_summoners(match) do
    match
    |> get_in(["info", "participants"])
    |> Enum.map(fn participant ->
      %{puuid: participant["puuid"], summoner_name: participant["summonerName"]}
    end)
  end

  def get_newest_match(puuid, region, start_time) do
    puuid
    |> fetch_recent_match_ids!(region, start_time, 1)
    |> List.first
  end

  def get_match_data(match_ids, region) do
    match_ids
      |> Enum.map(&Task.async(fn -> fetch_match_data!(&1, region) end))
      |> Enum.map(&Task.await(&1))
      |> Enum.map(fn match -> Blitz.RiotAPI.get_list_of_participant_summoners(match) end)
      |> List.flatten()
      |> Enum.uniq_by(fn participant -> participant.puuid end)
  end
end
