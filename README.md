# Memento Mori

A bar widget counting the days remaining against a birth year and a life
expectancy, with a click-to-configure popup and a reminder at every boot.

The stock `omarchy.clock` plugin already carries this idea as a progress bar
inside its calendar popup. This is the number on its own, always in view, and
kept as a separate plugin so the packaged clock stays untouched and keeps
receiving updates.

## Install

```bash
omarchy plugin add https://github.com/lookiyam-94/omarchy-memento-mori.git --enable
```

Then click the widget and enter a birth year. Until one is set the widget
shows `—`.

The startup notification is optional and not installed by the command above.
See [Startup notification](#startup-notification) to turn it on.

### Requirements

The bar widget needs nothing beyond Omarchy Quattro. The optional startup
notification uses `python3`, `notify-send` (libnotify) and `busctl` (systemd),
all present on a stock Omarchy install. `node` is only needed to run the
tests. The plugin needs no network access or elevated privileges, and writes
nothing outside this widget's own `shell.json` entry.

## Using it

**Click the widget** to open the settings popup. It shows the count, the
percentage lived, and the two fields behind them:

```
                MEMENTO MORI
                   12,179
        days remaining · 52% lived
   BORN [ 1990 ]      LIVE TO [ 70 ]
   enter saves · tab switches · esc closes
```

`Enter` saves and closes, `Tab` moves between fields, `Esc` discards. Saving
writes straight back into this widget's `shell.json` entry through the same
`updateEntryInline` path the stock clock uses for its own settings, so the
panel and the config can never drift apart. Keys the panel does not know about
(a hand-edited `format`) survive a save untouched.

**BORN takes either precision.** A bare year (`1990`) or a full date
(`1990-06-17`). A full date wins when set; typing a bare year clears a
previously saved date, on the grounds that the year you just entered is the
more recent word on the subject.

## Settings

The panel is the easy path, but the same keys can be edited directly in
`~/.config/omarchy/shell.json`. The shell hot-reloads on save.

| Key | Default | Meaning |
| --- | --- | --- |
| `birthYear` | *(unset)* | Four-digit year. Unset, malformed, in the future, or more than 120 years back leaves the widget showing `—`. |
| `lifeExpectancy` | `90` | Whole years. Values outside 1–150 fall back to the default. |
| `birthDate` | *(unset)* | Optional `"YYYY-MM-DD"`. Takes precedence over `birthYear`. |
| `format` | `"{days}"` | Label template; `{days}` is replaced by the count. |

```json
{
  "id": "lookiyam.memento",
  "birthYear": 1990,
  "lifeExpectancy": 70,
  "format": "{days}d"
}
```

## Startup notification

An optional post-boot hook fires once per boot:

> **12,179 days remaining · 52% lived**
> “You only live once, but if you do it right, once is enough.” — Mae West

It reads the same `shell.json` entry the widget reads, so the two are always
configured alike, and it waits for the notification daemon to appear on the
bus before sending — at `post-boot` time the shell that owns that daemon is
still coming up, and a notification sent too early goes nowhere.

It ships in this repository but is never installed for you. To turn it on,
copy it into Omarchy's hook directory:

```bash
mkdir -p ~/.config/omarchy/hooks/post-boot.d
cp ~/.config/omarchy/plugins/lookiyam.memento/hooks/post-boot.d/memento-mori \
   ~/.config/omarchy/hooks/post-boot.d/
```

Run the copied file directly to preview it. Delete it to turn it off.

### The daily quote

Quotes live in `quotes.txt` next to this file, one per line, `#` for comments.
Add, remove, or replace them freely — the list can be any length.

The pick is **not random**. The index is the countdown itself:

```bash
quotes[ days % quote_count ]
```

`days` already changes exactly once a day, so the quote holds steady across a
second reboot or a manual preview and still turns over tomorrow — which is
what "changes daily" actually asks for, and what `shuf` or `$RANDOM` would
get wrong. With 29 quotes the list cycles every 29 days.

Two constraints on anything you add:

- **No `&` or `<`.** Some notification daemons parse the body as markup and
  will mangle or swallow the line.
- **Keep it under roughly 110 characters.** The popup wraps about three lines
  before it ellipsizes. The notification centre's list view truncates at two
  lines regardless — that is its own display limit, not a lost quote.

`test-hook.sh` checks all of this.

## Precision

With only `birthYear`, the endpoint can be no better than **January 1** of
that year plus the expectancy — right to the day, but anchored to the turn of
the year, so it is off by however far the real birthday sits from January 1.
Setting `birthDate` anchors it exactly. Either way the number decrements once
per day.

## Note on the percentage

The tooltip and popup compute "% lived" in **days**, while the clock's own bar
uses **whole years** (`age / expectancy`). The two can differ by a point —
for 1990 and 70 years on 2026-08-28: 52% here, 51% in the clock popup. Both are correct for their method;
this one is finer-grained.

Your birth year and expectancy live in two places (this entry and the
`omarchy.clock` entry) and are not shared — a plugin can only read its own
settings. Changing one here does not change the clock's copy.

## Layout

Horizontal bars only. On a vertical bar the label will be clipped; the stock
clock handles that case with a stacked `OpticalGlyph` column if you ever need
it.

## IPC

```bash
omarchy-shell lookiyam.memento days      # the raw count
omarchy-shell lookiyam.memento toggle    # open/close the settings popup
omarchy-shell lookiyam.memento refresh   # recompute now
```

Note that opening the popup takes keyboard focus, so anything typed
afterwards lands in its fields.

## Testing

`Model.js` is deliberately Qt-free, so the date math runs under plain node:

```bash
tests/test.sh        # 19 assertions on the model
tests/test-hook.sh   # the boot hook's math vs Model.js (23 configurations),
                     # plus the quote list's health
```

The hook reimplements the date math in python because node is not part of a
stock Omarchy install and is rarely on `PATH` during a boot, while `python3` is
in `/usr/bin`. `test-hook.sh` lifts the python straight out of
`hooks/post-boot.d/memento-mori` and checks it against `Model.js` across
ordinary, malformed, and past-the-end configurations, so the two
implementations cannot drift apart.

## Remove

```bash
omarchy plugin remove lookiyam.memento
```

If you installed the startup notification, delete it too:

```bash
rm -f ~/.config/omarchy/hooks/post-boot.d/memento-mori
```

## License

[MIT](LICENSE)
