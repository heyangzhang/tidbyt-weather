"""
Day Weather — a day-of weather app for Tidbyt.

Layout (64x32):
  ┌───────────────────────────────────────┐
  │ [icon] 47°                  H52  L38 │  current conditions + today's range
  │ Rain ~2p 70%                         │  the one thing you need to know today
  │ ▁▂▅▇▅▂ temp line over rain bars      │  next 16 hours, 1 column per hour
  └───────────────────────────────────────┘

Data: Open-Meteo (free, no API key). Responses are cached for 10 minutes.
"""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API_URL = "https://api.open-meteo.com/v1/forecast"
CACHE_TTL = 600
HOURS = 16  # columns in the bottom strip, 4 px each

DEFAULT_LOCATION = json.encode({
    "lat": "40.4617",
    "lng": "-79.9447",
    "description": "Friendship, Pittsburgh, PA",
    "locality": "Pittsburgh",
    "timezone": "America/New_York",
})

# Colors
WHITE = "#FFFFFF"
DIM = "#9AA0A8"
HIGH = "#FF9A3C"
LOW = "#5FB0FF"
RAIN_TXT = "#7CC4FF"
SNOW_TXT = "#E8F2FF"
STORM_TXT = "#FFD84A"
DRY_TXT = "#A8E6A1"
TEMP_LINE = "#FFB066"

ICONS = {
    "clear_day": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAa0lEQVR42rWSyw3AIAxDX1DnYYJOxECdiAlYKD1V5ZcCqvDRsZM4CuyCRvSr7maFq7ohxJxwvRMk9HViGn1GpH4DNzQC+HKTwqwRXTnYoz0A5LSzNzkzbbO2BIRUkUbmX9fe94qz3N5X7OEGKZ4w4twMApIAAAAASUVORK5CYII=",
    "clear_night": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAO0lEQVR42mNgGFTg2bMT/2mukYkSG5kocSoTJWFDfc3EeoGJklCHa5aSsmAk1QCSNKBbwERIASHxgQEAFqseXvQtiXYAAAAASUVORK5CYII=",
    "partly_day": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAhklEQVR42mNgwAL+H2H4z0AEYCJGMbGGkQQYMWyZhrCFMQtTHqfm/9MY/jPoIQlcwm8AI8w/jDYMjMiaz/HdQVFo9EmFgdEG1SAWdAFsGhFiKvj9fPbSHbwha6ynwogSVcRqRFfDCItHbE4l5AJGYm3EmcLIBUzogUCKs1lgnK07djHQFQAAR8gy0CGg5U4AAAAASUVORK5CYII=",
    "partly_night": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAaElEQVR42mNgQAPPnp34z0AqePbsxH9SNTIxUACYyHYqNptJMYgFl8TZS3dQDDHWU2FEV8OIzcbnb0SwGohuAIazcWnE5hpGfJK4AMwFTKRqRFbLSKpG6iYSbNFAjL/h8bx1xy4GugIAiGsy+0mYQkYAAAAASUVORK5CYII=",
    "cloudy": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAhUlEQVR42mNkwAKauqb9xyZeV5bFiMxnIlYjNjkmYjViU8NEikZ0tYy4NHp7uKHwt+7YhWEIEzaT0TXiEmNCD0VsirDJ1ZVlMcJtvnH1Ml6NyAbcuHqZAe5nBgYGhrOX7hAdYAwMDAzGeiqMjORoxBtgJGk21lNhJFWjsZ4KIwu+eBy8AAB1QzEBy7GciAAAAABJRU5ErkJggg==",
    "fog": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAK0lEQVR42mNgGJKAEcZYsHT9f2I1JUQHMg6ws4eWczFCm5xQH2BnD70QBwAT0g74PEQIKwAAAABJRU5ErkJggg==",
    "rain": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAX0lEQVR42mNkwAGauqb9R+bXlWUxoqthIkYjLjEmYhThkmMiViM2NUykaERXy0iqRoIBRpJmbNFACNSVZTGywDg3rl5mGDhg0/P/P1ny2CSQxQgZTJIriNZItEGkaAQAdIc8tsD30s8AAAAASUVORK5CYII=",
    "snow": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAY0lEQVR42mNkwAHOXrrzH5lvrKfCiK6GiRiNuMSYiFGES46JWI3Y1DCRohFdLSOpGgkGGEmasUUDIWCsp8LIAuNs3bGLYYiCDz/+/ydFHiW0lx3DrxhdHi+Ytu//f4qdj8s7AJN2QDpqWFXMAAAAAElFTkSuQmCC",
    "storm": "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAb0lEQVR42mNkwAKauqb9xyZeV5bFiMxnIlYjNjkmYjViU8NEikZ0tYykasTrZ5I1o4ciMaCuLIuRBca5cfUyA9XB/zsa///f0fhPdY0oAWbT8/8/IUOwqkEXhGnAp5ERl00oilRuMA6ewGJgYGAAAPQ2VO1GyWMXAAAAAElFTkSuQmCC",
}

# ---------------------------------------------------------------------------
# WMO weather codes -> icon / precipitation kind
# ---------------------------------------------------------------------------

def icon_for(code, is_day):
    if code == 0 or code == 1:
        return "clear_day" if is_day else "clear_night"
    if code == 2:
        return "partly_day" if is_day else "partly_night"
    if code == 3:
        return "cloudy"
    if code == 45 or code == 48:
        return "fog"
    if (code >= 71 and code <= 77) or code == 85 or code == 86:
        return "snow"
    if code >= 95:
        return "storm"
    if code >= 51:
        return "rain"
    return "cloudy"

def precip_kind(code):
    """Name for precipitation at this hour: Snow, Storms, or Rain."""
    if (code >= 71 and code <= 77) or code == 85 or code == 86:
        return "Snow"
    if code >= 95:
        return "Storms"
    return "Rain"

def is_wet_code(code):
    return code >= 51

def kind_color(kind):
    return {"Snow": SNOW_TXT, "Storms": STORM_TXT}.get(kind, RAIN_TXT)

def short_hour(t):
    """2pm -> '2p', 12am -> '12a'."""
    return t.format("3pm")[:-1]

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

def fetch(config, loc, celsius):
    base = config.get("api_url") or API_URL  # api_url: hidden override for local testing
    url = "%s?latitude=%s&longitude=%s&current=temperature_2m,weather_code,is_day" % (base, loc["lat"], loc["lng"])
    url += "&hourly=temperature_2m,precipitation_probability,weather_code"
    url += "&daily=temperature_2m_max,temperature_2m_min,sunset&forecast_days=2&timezone=auto"
    if not celsius:
        url += "&temperature_unit=fahrenheit"
    resp = http.get(url, ttl_seconds = CACHE_TTL)
    if resp.status_code != 200:
        return None
    return resp.json()

def headline(hourly, start, tz, now, sunset):
    """The single most useful sentence for the rest of the day."""
    probs = hourly["precipitation_probability"]
    codes = hourly["weather_code"]
    window = min(start + 12, len(probs))

    # Wet right now: when does it stop?
    if probs[start] >= 60 and is_wet_code(codes[start]):
        kind = precip_kind(codes[start])
        for i in range(start + 1, window):
            if probs[i] < 40:
                t = time.parse_time(hourly["time"][i], format = "2006-01-02T15:04", location = tz)
                return ("%s til %s" % (kind, short_hour(t)), kind_color(kind))
        return ("%s all day" % kind, kind_color(kind))

    # Wet later: when does it start?
    for i in range(start + 1, window):
        if probs[i] >= 50:
            kind = precip_kind(codes[i]) if is_wet_code(codes[i]) else "Rain"
            t = time.parse_time(hourly["time"][i], format = "2006-01-02T15:04", location = tz)
            return ("%s ~%s %d%%" % (kind, short_hour(t), probs[i]), kind_color(kind))

    # Only a slight chance
    peak = max(probs[start:window])
    if peak >= 25:
        return ("Maybe rain %d%%" % peak, RAIN_TXT)

    # Dry: give the next most useful fact
    if sunset != None and now < sunset:
        return ("Dry, dusk %s" % sunset.format("3:04"), DRY_TXT)
    return ("Dry tonight", DRY_TXT)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def degree(color):
    # Most Pixlet fonts lack a degree glyph, so draw a small 3x3 ring.
    ring = render.Stack(children = [
        render.Box(width = 3, height = 3, color = color),
        render.Padding(pad = (1, 1, 0, 0), child = render.Box(width = 1, height = 1, color = "#000")),
    ])
    return render.Padding(pad = (1, 1, 0, 0), child = ring)

def top_row(current, daily):
    temp = int(current["temperature_2m"] + 0.5) if current["temperature_2m"] >= 0 else int(current["temperature_2m"] - 0.5)
    icon = ICONS[icon_for(int(current["weather_code"]), current["is_day"] == 1)]
    hi = int(daily["temperature_2m_max"][0] + 0.5)
    lo = int(daily["temperature_2m_min"][0] + 0.5)

    left = render.Row(
        cross_align = "center",
        children = [
            render.Image(src = base64.decode(icon), width = 15, height = 15),
            render.Box(width = 2, height = 1),
            render.Text(str(temp), font = "6x13", color = WHITE),
            render.Column(children = [degree(WHITE), render.Box(width = 1, height = 9)]),
        ],
    )
    right = render.Column(
        cross_align = "end",
        children = [
            render.Text("H%d" % hi, font = "tom-thumb", color = HIGH),
            render.Box(width = 1, height = 1),
            render.Text("L%d" % lo, font = "tom-thumb", color = LOW),
        ],
    )
    return render.Box(
        width = 64,
        height = 16,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [left, render.Padding(pad = (0, 1, 1, 0), child = right)],
        ),
    )

def rain_bar_color(prob, code):
    if (code >= 71 and code <= 77) or code == 85 or code == 86:
        return "#C8D8F0"
    if prob >= 60:
        return "#2F7BFF"
    if prob >= 30:
        return "#1E4FA8"
    return "#163463"

def bottom_strip(hourly, start):
    n = min(HOURS, len(hourly["time"]) - start)
    temps = hourly["temperature_2m"][start:start + n]
    probs = hourly["precipitation_probability"][start:start + n]
    codes = hourly["weather_code"][start:start + n]

    # Rain-chance bars: 3 px wide + 1 px gap, height scaled to 0..8 px.
    bars = []
    for i in range(n):
        h = (probs[i] * 8 + 50) // 100
        bar = render.Box(width = 3, height = h, color = rain_bar_color(probs[i], codes[i])) if h > 0 else render.Box(width = 3, height = 1, color = "#0B1730")
        bars.append(render.Padding(pad = (0, 0, 1, 0), child = render.Column(
            main_align = "end",
            expanded = True,
            children = [bar],
        )))

    # Temperature line, x-aligned to bar centers (x = 4i + 1.5 px).
    lo, hi = min(temps), max(temps)
    if hi - lo < 4:
        mid = (hi + lo) / 2.0
        lo, hi = mid - 2, mid + 2
    line = render.Plot(
        data = [(i, temps[i]) for i in range(n)],
        width = 64,
        height = 8,
        color = TEMP_LINE,
        x_lim = (-0.375, 15.375),
        y_lim = (lo - 0.5, hi + 0.5),
    )

    return render.Box(width = 64, height = 8, child = render.Stack(children = [
        render.Row(children = bars),
        line,
    ]))

def message(text, color = DIM):
    return render.Root(child = render.Box(child = render.WrappedText(text, color = color, align = "center", width = 60)))

def main(config):
    loc = json.decode(config.get("location", DEFAULT_LOCATION))
    celsius = config.bool("celsius", False)
    tz = loc.get("timezone", "America/New_York")

    data = fetch(config, loc, celsius)
    if data == None:
        return message("Weather unavailable")
    tz = data.get("timezone", tz)

    now = time.now().in_location(tz)
    hourly = data["hourly"]

    # JSON numbers arrive as floats (and occasionally null); normalize to ints.
    hourly["precipitation_probability"] = [int(p) if p != None else 0 for p in hourly["precipitation_probability"]]
    hourly["weather_code"] = [int(c) if c != None else 0 for c in hourly["weather_code"]]
    hourly["temperature_2m"] = [t if t != None else 0.0 for t in hourly["temperature_2m"]]
    key = now.format("2006-01-02T15") + ":00"
    start = 0
    for i, t in enumerate(hourly["time"]):
        if t == key:
            start = i
            break

    sunset = None
    if data["daily"].get("sunset"):
        sunset = time.parse_time(data["daily"]["sunset"][0], format = "2006-01-02T15:04", location = tz)

    text, color = headline(hourly, start, tz, now, sunset)

    return render.Root(
        max_age = CACHE_TTL,
        child = render.Column(children = [
            top_row(data["current"], data["daily"]),
            render.Box(width = 64, height = 8, child = render.Marquee(
                width = 62,
                align = "center",
                child = render.Text(text, font = "tom-thumb", color = color),
            )),
            bottom_strip(hourly, start),
        ]),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Where to show the forecast for.",
                icon = "locationDot",
            ),
            schema.Toggle(
                id = "celsius",
                name = "Celsius",
                desc = "Show temperatures in °C instead of °F.",
                icon = "temperatureHalf",
                default = False,
            ),
        ],
    )
