#!/usr/bin/env bash
# Render a Pixlet app and push it into the Tidbyt's rotation as its own slot.
#
#   ./push.sh apps/weather/weather.star weather
#   ./push.sh apps/movies/movies.star movies api_key="$TMDB_API_KEY"
#
# Args: <app .star file> <installation id> [config key=value ...]
# Env (from the Tidbyt phone app, device settings > General > Get API Key):
#   TIDBYT_API_TOKEN, TIDBYT_DEVICE_ID
set -euo pipefail

APP="${1:?usage: push.sh <app.star> <installation-id> [key=value ...]}"
ID="${2:?usage: push.sh <app.star> <installation-id> [key=value ...]}"
shift 2

: "${TIDBYT_API_TOKEN:?set TIDBYT_API_TOKEN}"
: "${TIDBYT_DEVICE_ID:?set TIDBYT_DEVICE_ID}"

OUT="$(mktemp -t "$ID.XXXXXX").webp"
trap 'rm -f "$OUT"' EXIT

pixlet render "$APP" "$@" -o "$OUT"
pixlet push --api-token "$TIDBYT_API_TOKEN" --installation-id "$ID" --background \
  "$TIDBYT_DEVICE_ID" "$OUT"
