# Day Weather for Tidbyt

A day-of weather app for a stock Tidbyt, built with [Pixlet](https://github.com/tidbyt/pixlet). The app lives in `apps/weather/`. GitHub Actions renders it and pushes it to the device every 10 minutes, as the slot `dayweather` (see `.github/workflows/push.yml`).

The screen has three rows:

1. **Now:** a condition icon, the current temperature, and today's high and low.
2. **Headline:** the one thing worth knowing for the rest of the day, such as `Rain ~2p 70%`, `Rain til 4p`, `Snow ~7a 62%`, `Maybe rain 30%`, or `Dry, dusk 5:04`.
3. **Next 16 hours:** one column per hour. Blue bars show the chance of rain (light bars mean snow), and an orange line shows the temperature trend.

Data comes from [Open-Meteo](https://open-meteo.com), which is free and needs no key. The app defaults to Friendship, Pittsburgh, in °F.

## Secrets (Settings → Secrets and variables → Actions)

`TIDBYT_DEVICE_ID` and `TIDBYT_API_TOKEN`, from the Tidbyt app (device settings → General → Get API Key).

## Local use

```bash
pixlet serve apps/weather/weather.star
./push.sh apps/weather/weather.star dayweather
```

To remove the app from the rotation:

```bash
pixlet delete --api-token "$TIDBYT_API_TOKEN" "$TIDBYT_DEVICE_ID" dayweather
```

## Notes

- Scheduled workflows are paused after 60 days with no commits. Re-enable them in the Actions tab.
- GitHub often starts scheduled runs a few minutes late.
- Each app needs its own folder, because Pixlet loads every `.star` file in a folder as one app.
