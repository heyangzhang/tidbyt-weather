# Day Weather for Tidbyt

A day-of weather app for the 64×32 Tidbyt. It shows three rows:

1. **Now:** a condition icon, the current temperature, and today's high and low.
2. **Headline:** the one thing worth knowing for the rest of the day. For example, `Rain ~2p 70%`, `Rain til 4p`, `Snow ~7a 62%`, `Maybe rain 30%`, or `Dry, dusk 5:04`.
3. **Next 16 hours:** one column per hour. Blue bars show the chance of rain (light bars mean snow), and the orange line shows the temperature trend.

The data comes from [Open-Meteo](https://open-meteo.com), which is free and needs no API key. The app defaults to Friendship, Pittsburgh, in °F.

## Preview

```bash
pixlet serve weather.star
```

Open the URL it prints. The config panel lets you change the location and switch to Celsius.

## Push to your Tidbyt

```bash
export TIDBYT_API_TOKEN=...   # Tidbyt app > device settings > General > Get API Key
export TIDBYT_DEVICE_ID=...
chmod +x push.sh && ./push.sh
```

Pushed images don't update themselves. To keep the data fresh, schedule the script on an always-on machine:

```cron
*/10 * * * * TIDBYT_API_TOKEN=... TIDBYT_DEVICE_ID=... /path/to/tidbyt-weather/push.sh >/dev/null 2>&1
```

`--installation-id dayweather` keeps the app as a single slot in the rotation, and every push replaces it. `--background` updates the slot without jumping the display to it.

To remove the app from the rotation:

```bash
pixlet delete --api-token "$TIDBYT_API_TOKEN" "$TIDBYT_DEVICE_ID" dayweather
```

## Other locations

```bash
TIDBYT_LOCATION='{"lat":"40.4406","lng":"-79.9959","timezone":"America/New_York"}' ./push.sh
```
