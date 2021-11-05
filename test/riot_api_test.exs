defmodule RiotAPITest do
  use ExUnit.Case
  # doctest RiotAPI

  test "region_host" do
    assert Blitz.RiotAPI.region_host("na1") == "https://americas.api.riotgames.com"
  end

  test "api_host" do
    assert Blitz.RiotAPI.api_host("na1") == "https://na1.api.riotgames.com"
  end

  test "valid_region?" do
    assert Blitz.RiotAPI.valid_region?("na1")
    assert not Blitz.RiotAPI.valid_region?("mars1")
  end
end
