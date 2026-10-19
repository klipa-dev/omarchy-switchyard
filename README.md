# Switchyard

Switchyard is an Omarchy shell plugin that decides which browser a clicked
link opens in, based on the link's host. Set a handful of host rules and it
opens Google Meet links in Chromium, a work tool as a Chromium web app, and
everything else in your regular browser, all without you ever seeing a
picker. It's for anyone who runs a non-Chromium browser as their default
(Zen, Firefox, ...) but still wants a few sites, or Chromium-only web apps,
to open in Chromium.

## Install

```sh
omarchy plugin add https://github.com/klipa-dev/omarchy-switchyard.git --enable
~/.config/omarchy/plugins/klipa.switchyard/bin/omarchy-switchyard activate
```

Optionally, put the CLI on your `PATH` so you can run it as just
`omarchy-switchyard`:

```sh
ln -s ~/.config/omarchy/plugins/klipa.switchyard/bin/omarchy-switchyard ~/.local/bin/omarchy-switchyard
```

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
desktop id in `~/.config/omarchy-switchyard/fallback`, which `activate`
writes from your current default browser (so a broken or missing
`rules.json` can never lose it; a missing or invalid `rules.json` just
means every link goes to the fallback, with a notification if the file is
invalid). A rule whose browser isn't installed behaves the same way: the
link opens in the fallback browser instead, with a notification.

## Activate

```sh
omarchy-switchyard activate [--fallback <desktop-id>]   # take over as the default browser
omarchy-switchyard deactivate                           # restore the previous default browser
```

`activate` records your current default browser as the fallback for links
that match none of your rules, then registers Switchyard as the default
instead. Run it again with `--fallback <desktop-id>` (for example
`--fallback firefox.desktop`) to pick a different fallback, or to set one
when no default browser was recorded yet. `deactivate` restores the
recorded fallback and leaves it on disk; it never deletes your rules or
your fallback choice.

## Status and log

```sh
omarchy-switchyard status
```

prints whether Switchyard is the current default browser, the recorded
fallback, whether `rules.json` is present and how many rules it has, and
the last few lines of the routing log. Every routing decision — matched
rule or fallback, and the browser it launched — is appended to
`~/.local/state/omarchy-switchyard/log` (the last 200 lines are kept).

## Update and uninstall

```sh
omarchy plugin update klipa.switchyard
```

To uninstall, deactivate first so your default browser is restored, then
remove the plugin:

```sh
omarchy-switchyard deactivate
omarchy plugin remove klipa.switchyard
```

## Limitations

- A link clicked inside a Chromium web-app window never reaches the
  handler; it opens directly in Chromium.
- While Switchyard is active, Omarchy's own web apps (every launcher with
  `Exec=omarchy-launch-webapp`) open in Chromium regardless of your
  fallback browser. Brave, Chrome, Edge, Vivaldi and Opera users with web
  apps installed should know this; `activate` warns when it applies. The
  real fix is upstream, in Omarchy's own web-app launcher.
- Running `omarchy default browser <x>` (or anything else that changes
  your default browser) deactivates Switchyard silently, since Switchyard
  is no longer the browser `xdg-settings` points to; `status` shows this
  as `active: no`. Run `activate` again to take over.

## Development

```sh
make check   # shellcheck, qmllint, bats, and the Omarchy plugin validator
```

Needs `bats`, `shellcheck`, `qmllint`, and an Omarchy install (for
`omarchy plugin validate`).
