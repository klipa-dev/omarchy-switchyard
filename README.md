# Switchyard

Switchyard is an Omarchy shell plugin that routes each link you click to the
browser you want it in, based on the link's host. Set a handful of host
rules and Switchyard opens Google Meet links in Chromium, a work tool as a
Chromium web app, and everything else in your regular browser, without you
ever seeing a picker.

Status: in development, not yet released.

## Rules

Switchyard reads `~/.config/omarchy-switchyard/rules.json`. Copy
`rules.example.json` there and edit it:

```json
{
  "version": 1,
  "rules": [
    { "host": "*.google.com", "target": "chromium.desktop" },
    { "host": "basecamp.com", "target": "webapp" },
    { "host": "github.com", "target": "zen.desktop" }
  ]
}
```

Each clicked link is matched against `rules` in order; the first rule whose
`host` fits wins. `host` is the link's host, lowercased, with any
`user:pass@`, port, path and query removed; only `http` and `https` links
have a host, so anything else (`mailto:`, a bare word, ...) always falls
through. A bare host like `basecamp.com` matches only that host, not a
subdomain; `*.example.com` matches `example.com` itself and any subdomain.

`target` is either a desktop id (`chromium.desktop`, `zen.desktop`, ...) or
the word `webapp`, which opens the link as a browser window with no
address bar or tabs, the way an installed web app does. The browser behind
`webapp` is whichever Chromium-family browser Switchyard resolves itself:
the fallback browser below, if it is Chromium-family, otherwise
`chromium.desktop` — not necessarily the fallback browser itself.

A link that matches no rule goes to the fallback browser: the single
desktop id in `~/.config/omarchy-switchyard/fallback`, which
`omarchy-switchyard activate` writes from your current default browser (so
a broken or missing `rules.json` can never lose it; a missing or invalid
`rules.json` just means every link goes to the fallback, with a
notification if the file is invalid). Every routing decision is appended to
`~/.local/state/omarchy-switchyard/log` (the last 200 lines).

## Development

```sh
make check   # shellcheck, qmllint, bats, and the Omarchy plugin validator
```

Needs `bats`, `shellcheck`, `qmllint`, and an Omarchy install (for
`omarchy plugin validate`).
