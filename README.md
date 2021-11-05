# Blitz

Interview Challenge to monitor summoners a player has played with in the past few games.

## Running

Make a copy of `config.example.exs` and rename to `config.exs` replace `<your-api=key>` with your riot api-key.

```bash
mix deps.get
iex -S mix
Blitz.start("summoner-name", "region")
```

## Configurations

In `lib/blitz/summoner.ex` change `@check_milliseconds` to have the monitor check for matches more often
`@monitor_expires_seconds` to have the monitor stop sooner.

In `lib/blitz/riot_api.ex` change `@match_count` to change how much past games to fetch players from.
`@scale_ms_second` and `@limit_second` for rate limiting against a smaller interval.
`@scale_ms_minute` and `@limit_minute` for rate limiting against a larger interval.

Valid regions are `br1, eun1, euw1, jp1, kr, la1, la2, na1, oc1, tr1, ru`

## Future Considerations

1. The rate limiting implementation is not good enough. It seems that the Hammer library replenishes free spots quicker where Riot might be refreshing at a larger interval.
2. A lot of happy path only code. If data structures change from the API code will break.
3. A lot of miscellaneous improvements can be made. Some functions do too much, not enough unit testing, better configuration management, logging etc.
