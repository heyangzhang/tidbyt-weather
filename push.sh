#!/usr/bin/env bash
# Render the weather app and push it into the Tidbyt's rotation.
# Run this every ~10 minutes (see cron line in README.md) so the data stays fresh.
#
# Needs two env vars, both from the Tidbyt phone app (device settings > General > Get API Key):
#   TIDBYT_API_TOKEN, TIDBYT_DEVICE_ID
# Optional:
#   TIDBYT_LOCATION  JSON like {"lat":"40.4617","lng":"-79.9447","timezone":"America/New_York"}
#   TIDBYT_CELSIUS   true/false
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -t dayweather.XXXXXX).webp"
trap 'rm -f "$OUT"' EXIT

: "${TIDBYT_API_TOKEN:?set TIDBYT_API_TOKEN}"
: "${TIDBYT_DEVICE_ID:?set TIDBYT_DEVICE_ID}"

ARGS=()
[[ -n "${TIDBYT_LOCATION:-}" ]] && ARGS+=("location=${TIDBYT_LOCATION}")
[[ -n "${TIDBYT_CELSIUS:-}" ]] && ARGS+=("celsius=${TIDBYT_CELSIUS}")

# ${ARGS[@]+...} keeps macOS's bash 3.2 happy when ARGS is empty under `set -u`.
pixlet render "$DIR/weather.star" ${ARGS[@]+"${ARGS[@]}"} -o "$OUT"
pixlet push --api-token "$TIDBYT_API_TOKEN" --installation-id dayweather --background \
  "$TIDBYT_DEVICE_ID" "$OUT"
