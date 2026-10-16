# Isobar

Weather for [Omarchy](https://omarchy.org): a bar icon that shows the current
sky and turns red, orange or yellow when a weather alert is active, an
extended forecast popover, and a keyboard-first Weather app with a
precipitation radar and an animated ASCII sky.

Forecasts come from [Open-Meteo](https://open-meteo.com) (no API key); US
alerts come from the National Weather Service; radar from
[RainViewer](https://www.rainviewer.com), drawn over a base map built from
[Natural Earth](https://www.naturalearthdata.com) (public domain). Colors follow the active
Omarchy theme, except alerts and the AQI/UV meters: those use fixed colors,
since several themes repurpose their red.

## Install

```sh
git clone https://github.com/aronbohl/isobar ~/Projects/isobar
ln -s ~/Projects/isobar ~/.config/omarchy/plugins/io.github.aronbohl.isobar
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.aronbohl.isobar --after omarchy.clock
omarchy plugin disable omarchy.weather   # the stock widget, if it's in your bar
```

## Bar icon

| State      | Look                                             |
|------------|--------------------------------------------------|
| idle       | current sky (sun, moon, partly, cloud, rain, snow) |
| open       | underline                                        |
| alert      | advisory yellow · watch orange · warning red · emergency pulsing red (fixed colors, not the theme's) |
| offline    | dimmed; cached data stays visible                |

The popover shows current conditions with feels-like, wind, humidity and
today's range, any active alert, the next 24 hours as a temperature graph
(the same one as the app's hourly panel), and the next five days.

Click toggles the popover, right-click cycles saved locations, middle-click
opens the app. Plugins can't add their own key bindings, so to open the
popover from the keyboard, add one to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + W", "Isobar", "omarchy-shell shell call io.github.aronbohl.isobar popover ''")
```

From there, `↵` opens the app.

Popover keys: `←/→` (`h/l`) location · `↑/↓` (`j/k`) alert · `↵` open app ·
`u` units · `r` refresh · `Esc` close.

Watches, warnings and emergencies send one desktop notification per alert
(updates to an alert stay quiet). Emergencies stay until dismissed and break
through Do Not Disturb.

## App

Opens as a regular window from the popover (`↵`, footer, `DETAILS ›`) or by
middle-clicking the icon. To bind the app itself to a key instead, use
`toggle` in place of `popover` above. In a narrow window the location
sidebar tucks away; the header's "locations" button or `/` opens it as a
drawer.

The app shows the selected location's alerts and current conditions, then
¹ hourly (next 24h with a temperature line), ² 10-day (low–high bars on a
shared scale), ³ precipitation radar (the last 2 hours, looping), and tiles for air quality, UV, sunrise/sunset, wind, precipitation,
feels like, humidity, visibility, pressure and the moon.

Behind the hero, an ASCII sky matches the conditions: stars and shooting stars
at night, a pulsing sun, drifting clouds, slanting rain, lightning, snow, and
wind streaks above 35 km/h. `a` (or the header's "sky fx") freezes it on a
still frame, as does turning off Hyprland's animations. It only animates
while the app is the focused window and the sky is in view (animating costs
about 10% of one core).

Keys: `j/k` location · `J/K` reorder · `/` search · `0` expand/collapse alerts · `1-3` focus pane ·
`PgUp/PgDn/Space/Home/End` scroll · `m` full radar map (browser) ·
`p` pause/play radar · `u` units · `a` sky fx · `r` refresh · `x` remove ·
`?` cheatsheet · `q` close (`Esc` only unfocuses a pane). With the radar focused: `←/→` (`h/l`) step frames, `+/−`
zoom. The ▶/❚❚ button on the radar's timeline also pauses it.

The radar shows only past frames: RainViewer's free API no longer offers
forecast frames, serves zoom 7 at most, and has one color scheme. Coastlines,
borders and city names come from `data/basemap.json`, built from Natural Earth
1:50m with `node tools/build-basemap.js <geojson dir> > data/basemap.json`. In the search box, typing filters
saved locations; `↵` with no match (or "+ add location") searches places
online, then `↑/↓` and `↵` add one. Click an alert to read the full NWS text.

## Settings

Stored inline on the plugin's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.aronbohl.isobar",
  "locations": [{ "name": "Omaha", "region": "Nebraska, United States",
                  "latitude": 41.25626, "longitude": -95.94043, "countryCode": "US" }],
  "selected": 0,
  "units": "auto",
  "refreshMinutes": 15,
  "scrollSpeed": 250,
  "skyFx": true
}
```

With no `locations`, the first one comes from the stock widget's
`~/.local/state/omarchy/settings/weather.json`. `units` is `auto` (from your
locale), `metric` or `imperial`. `scrollSpeed` (percent, 50–800) multiplies
touchpad scrolling in the app; 250 roughly offsets Omarchy's 0.4 touchpad
`scroll_factor`. Responses are cached in
`~/.cache/isobar/`.

## IPC

```sh
omarchy-shell shell call io.github.aronbohl.isobar toggle ''
omarchy-shell shell call io.github.aronbohl.isobar popover ''
omarchy-shell shell call io.github.aronbohl.isobar refresh ''
omarchy-shell shell call io.github.aronbohl.isobar next ''
```

## Development

```sh
omarchy plugin validate .
node --test tests/*.test.js
/usr/lib/qt6/bin/qmllint *.qml components/*.qml
```

Tests run against saved API responses in `tests/fixtures/`; they never hit the
network. When the plugin is symlinked into `~/.config/omarchy/plugins/`, the
shell doesn't pick up QML edits to the running widget or the keep-loaded
service; run `omarchy restart shell` after changes. Logs:
`quickshell log -p /usr/share/omarchy/shell -t 100`.

## License

MIT
