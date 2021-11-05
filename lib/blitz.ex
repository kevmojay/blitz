defmodule Blitz do
  def start(summoner_name \\ "GeneralSn1per", region \\ "na1") do
    region = region
              |> String.downcase()
              |> String.trim()

    if not Blitz.RiotAPI.valid_region?(region) do
      raise "Region invalid"
    end

    case Blitz.RiotAPI.fetch_summoner!(summoner_name, region) do
      %{"name" => _, "puuid" => puuid} ->
        match_ids = Blitz.RiotAPI.fetch_recent_match_ids!(puuid, region)
        match_players = Blitz.RiotAPI.get_match_data(match_ids, region)
        children_summoners = Enum.map(match_players, fn player -> {Blitz.Summoner, [
                                  player.puuid,
                                  player.summoner_name,
                                  region,
                                  self()
                                ]}end)
        opts = [strategy: :one_for_one]
        Supervisor.start_link(children_summoners, opts)
        Enum.map(match_players, fn player -> player.summoner_name end)
      _ ->
        raise "Summoner not found."
    end    
  end
end
