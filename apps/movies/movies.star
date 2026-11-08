"""
Coming Soon — the most-anticipated theatrical releases, for Tidbyt.

Cycles through up to 5 films, ~3 s each:
  ┌──────┬───────────────────────────┐
  │poster│ Title wraps over          │
  │21x32 │ up to three lines         │
  │      │ Fri Nov 14                │
  │      │ in 6 days  /  OUT NOW     │
  └──────┴───────────────────────────┘

"Anticipated" = TMDB popularity among films with a US theatrical (or limited)
release from 6 days ago through the next 6 weeks. Dates shown are the US
theatrical dates, not the world premiere.

Data: TMDB API (free key, passed in as the `api_key` config value).
"""

load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API = "https://api.themoviedb.org/3"
IMG = "https://image.tmdb.org/t/p/w92"
TTL = 6 * 3600
TZ = "America/New_York"
MAX_FILMS = 5
LOOKBACK_DAYS = 6  # keep showing a film through its opening week
LOOKAHEAD_DAYS = 42
FRAMES_PER_CARD = 30  # x 100 ms = 3 s per film

TITLE = "#FFFFFF"
DATE = "#9AA0A8"
SOON = "#FFC94A"
OUT = "#7CE38B"

def api_base(config):
    return config.get("api_url") or API  # api_url / img_url: hidden overrides for local testing

def get_json(config, path, params):
    url = "%s%s?api_key=%s&%s" % (api_base(config), path, config.get("api_key"), params)
    resp = http.get(url, ttl_seconds = TTL)
    if resp.status_code != 200:
        return None
    return resp.json()

def us_theatrical_date(config, movie_id, tz):
    """Earliest US limited (2) or theatrical (3) release date, or None."""
    data = get_json(config, "/movie/%d/release_dates" % movie_id, "")
    if data == None:
        return None
    best = None
    for country in data.get("results", []):
        if country.get("iso_3166_1") != "US":
            continue
        for rd in country.get("release_dates", []):
            if int(rd.get("type", 0)) not in (2, 3):
                continue
            t = time.parse_time(rd["release_date"][:10], format = "2006-01-02", location = tz)
            if best == None or t < best:
                best = t
    return best

def pick_films(config, today, tz):
    lo = (today - time.parse_duration("%dh" % (24 * LOOKBACK_DAYS))).format("2006-01-02")
    hi = (today + time.parse_duration("%dh" % (24 * LOOKAHEAD_DAYS))).format("2006-01-02")
    params = "region=US&with_release_type=2|3&release_date.gte=%s&release_date.lte=%s" % (lo, hi)
    params += "&sort_by=popularity.desc&include_adult=false&language=en-US&page=1"
    data = get_json(config, "/discover/movie", params)
    if data == None:
        return None

    films = []
    for m in data.get("results", []):
        if not m.get("poster_path"):
            continue
        date = us_theatrical_date(config, int(m["id"]), tz)
        if date == None:
            continue
        days = int((date - today).hours / 24 + 0.5)
        if days < -LOOKBACK_DAYS or days > LOOKAHEAD_DAYS:
            continue
        films.append({"title": m["title"], "poster": m["poster_path"], "date": date, "days": days})
        if len(films) == MAX_FILMS:
            break

    # Show in release order: what's out now first, then the soonest.
    return sorted(films, key = lambda f: f["days"])

def countdown(days):
    if days <= 0:
        return ("OUT NOW", OUT)
    if days == 1:
        return ("Tomorrow", SOON)
    if days < 14:
        return ("in %d days" % days, SOON)
    return ("in %d wks" % (days // 7), DATE)

def poster(config, path):
    base = config.get("img_url") or IMG
    resp = http.get(base + path, ttl_seconds = 7 * 24 * 3600)
    if resp.status_code != 200:
        return render.Box(width = 21, height = 32, color = "#222")
    return render.Image(src = resp.body(), width = 21, height = 32)

def card(config, f):
    label, color = countdown(f["days"])
    text = render.Column(
        expanded = True,
        main_align = "space_between",
        children = [
            render.Box(
                width = 42,
                height = 18,
                child = render.Column(
                    expanded = True,
                    children = [render.WrappedText(f["title"], font = "tom-thumb", color = TITLE, width = 42, height = 18)],
                ),
            ),
            render.Column(children = [
                render.Text(f["date"].format("Mon Jan 2"), font = "tom-thumb", color = DATE),
                render.Text(label, font = "tom-thumb", color = color),
            ]),
        ],
    )
    return render.Row(children = [
        poster(config, f["poster"]),
        render.Box(width = 1, height = 32),
        render.Padding(pad = (0, 0, 0, 0), child = text),
    ])

def message(text):
    return render.Root(child = render.Box(child = render.WrappedText(text, color = DATE, align = "center", width = 60)))

def main(config):
    if not config.get("api_key"):
        return message("Add a TMDB API key")

    today = time.parse_time(time.now().in_location(TZ).format("2006-01-02"), format = "2006-01-02", location = TZ)
    films = pick_films(config, today, TZ)
    if films == None:
        return message("Movies unavailable")
    if not films:
        return message("No big releases soon")

    cards = [render.Animation(children = [card(config, f)] * FRAMES_PER_CARD) for f in films]
    return render.Root(delay = 100, max_age = TTL, child = render.Sequence(children = cards))

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "TMDB API key",
                desc = "Your TMDB v3 API key.",
                icon = "key",
            ),
        ],
    )
