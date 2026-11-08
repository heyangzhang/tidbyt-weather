# Tidbyt apps

Custom [Pixlet](https://github.com/tidbyt/pixlet) apps for a stock Tidbyt. GitHub Actions renders each app on a schedule and pushes it to the device, so no home server is needed.

| App | Folder | Slot ID | Refresh | Data |
|---|---|---|---|---|
| Day Weather | `apps/weather` | `dayweather` | every 10 min | [Open-Meteo](https://open-meteo.com) (no key) |
| Coming Soon | `apps/movies` | `movies` | daily | [TMDB](https://www.themoviedb.org) (free key) |

Each app has its own folder because Pixlet loads every `.star` file in a folder as one app.

## Day Weather

The screen has three rows:

1. A condition icon, the current temperature, and today's high and low.
2. A headline for the rest of the day, such as `Rain ~2p 70%` or `Dry, dusk 5:04`.
3. The next 16 hours: rain-chance bars with a temperature line on top.

It defaults to Friendship, Pittsburgh, in °F.

## Coming Soon

This app shows the most-anticipated theatrical releases. It picks the top 5 films by TMDB popularity among those with a US theatrical or limited release between 6 days ago and 6 weeks from now. It then shows them in release order, about 3 seconds each, with the poster, title, US release date, and `OUT NOW`, `Tomorrow`, or `in N days`.

## Secrets (repo Settings → Secrets and variables → Actions)

- `TIDBYT_DEVICE_ID`, `TIDBYT_API_TOKEN`: from the Tidbyt app (device settings → General → Get API Key)
- `TMDB_API_KEY`: the TMDB v3 API key, from themoviedb.org → Settings → API

## Local use

```bash
pixlet serve apps/weather/weather.star
pixlet serve apps/movies/movies.star          # enter the TMDB key in the config panel
./push.sh apps/movies/movies.star movies api_key="$TMDB_API_KEY"
```

To remove a slot:

```bash
pixlet delete --api-token "$TIDBYT_API_TOKEN" "$TIDBYT_DEVICE_ID" <slot-id>
```

## Notes

- Scheduled workflows are paused after 60 days with no commits. Re-enable them in the Actions tab.
- GitHub often starts scheduled runs a few minutes late.
