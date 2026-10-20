# Switchyard

Open the sites you choose as web apps, from any link you click on Omarchy.

You probably run one browser as your default — Zen, Firefox, whatever you
like. But a handful of sites are nicer as their own window: a video call, a
Basecamp project, a work dashboard, with no address bar or tabs, the way an
installed web app looks. Switchyard lets you say which sites get that
treatment, and which browser the rest should open in, then takes over as
the system's link handler so every click just goes to the right place.

## Why you'd want it

- A meeting link or a Basecamp task shared in chat opens as its own app
  window, not another tab in your browser.
- A site that only works well in Chromium opens there, even though your
  default browser is Zen, Firefox, or anything else.
- Everything you didn't add a rule for — search results, articles, random
  links — keeps opening in your usual browser, exactly as before.
- No picker ever appears. Switchyard decides once, from the rules you
  wrote, and launches straight to the right place.

## Quick start

Install the plugin and put its CLI on your `PATH`:

```sh
omarchy plugin add https://github.com/klipa-dev/omarchy-switchyard.git --enable
ln -s ~/.config/omarchy/plugins/benviu.switchyard/bin/omarchy-switchyard ~/.local/bin/omarchy-switchyard
```

`omarchy plugin add` warns that plugins run unsandboxed and asks you to
confirm, then ends with `Enabled benviu.switchyard`; the `ln -s` prints
nothing.

Take over as the default browser:

```sh
omarchy-switchyard activate
```
```
Switchyard is the default browser; unmatched links open in zen.desktop
```

(`zen.desktop` here is whatever browser was already your default — Switchyard
records it automatically, so you don't lose it.)

Add your first rule:

```sh
omarchy-switchyard rules add youtube.com webapp
```
```
Rule added: *.youtube.com → webapp
Saved as *.youtube.com, which matches youtube.com and all its subdomains.
```

See what a click on a matching link would do, without opening anything:

```sh
omarchy-switchyard open --dry-run https://www.youtube.com/@omarchy
```
```
setsid uwsm-app -- /usr/bin/chromium --app=https://www.youtube.com/@omarchy
```

That's the web app window about to open. Click a real YouTube link now and
it opens the same way.

## Rules

Switchyard reads `~/.config/omarchy-switchyard/rules.json`. Copy
`rules.example.json` there and edit it by hand, or use the CLI below:

```json
{
  "version": 1,
  "rules": [
    { "host": "basecamp.com", "target": "webapp" },
    { "host": "*.youtube.com", "target": "webapp" },
    { "host": "*.google.com", "target": "chromium.desktop" }
  ]
}
```

Each clicked link is matched against `rules` in order, and the first rule
whose `host` fits wins; only `http` and `https` links have a host, so
anything else (`mailto:`, a bare word, ...) always falls through. A host
covers the site and all its subdomains: `basecamp.com` and `*.basecamp.com`
are the same rule, and both match `www.basecamp.com` too, so there's no way
to match a host and exclude its subdomains.

`target` is the word `webapp`, which opens the link as a browser window
with no address bar or tabs, the way an installed web app does, or a
desktop id (`chromium.desktop`, `zen.desktop`, ...), which opens the link
in that browser's ordinary window instead. The browser behind `webapp` is
whichever Chromium-family browser Switchyard resolves itself: the fallback
browser below, if it is Chromium-family, otherwise `chromium.desktop`.

A link that matches no rule goes to the fallback browser: the desktop id
`activate` recorded from your current default browser. A missing
`rules.json` falls back the same way, silently; an invalid one, or a rule
whose browser isn't installed, falls back with a notification.

### Editing rules from the command line

You can skip hand-editing `rules.json` and use the CLI instead:

```sh
omarchy-switchyard rules list [--json]            # show the configured rules
omarchy-switchyard rules add <host> <target>      # add a rule, or replace the one for <host>
omarchy-switchyard rules remove <host>             # remove the rule for <host>
omarchy-switchyard fallback [<desktop-id>]         # show, or set, the fallback browser
omarchy-switchyard browsers [--json]               # list installed browsers
```

`<host>` can be a bare host (`youtube.com`), a `*.`-prefixed one
(`*.youtube.com`), or a full URL (`https://www.youtube.com/watch?v=x`);
whatever you type is normalised and saved as `*.<host>`, stripping a
leading `*.` or `www.` first. Each command prints what it did:

```
Rule added: *.youtube.com → webapp
Rule changed: *.youtube.com → webapp (replaces www.youtube.com → chromium.desktop)
Rule changed: *.youtube.com → webapp (replaces *.youtube.com → webapp, www.youtube.com → chromium.desktop)
Rule unchanged: *.youtube.com → webapp
Rule removed: *.youtube.com
```

When what you typed is not already in that form, a second line says what
was saved: `Saved as *.youtube.com, which matches youtube.com and all its
subdomains.`

A `Rule changed` lists, in the parenthetical, every existing rule the
write replaced. `browsers` lists every installed browser's desktop id and
name, useful for picking a `<target>` or a fallback. If `rules.json` is
invalid, every `rules` command fails, `rules list` included, and names the
file to fix by hand.

## Command reference

| Command | What it does |
| --- | --- |
| `activate [--fallback <desktop-id>]` | Register Switchyard as the default browser. |
| `deactivate` | Restore the browser that was default before `activate`. |
| `status [--json]` | Show whether Switchyard is active, and recent log lines. |
| `open [--dry-run] [flags] <url>` | Route and launch `<url>` the way a clicked link would. |
| `rules list [--json]` | Show the configured rules. |
| `rules add <host> <target>` | Add a rule, or replace the one for `<host>`. |
| `rules remove <host>` | Remove the rule for `<host>`. |
| `fallback [<desktop-id>]` | Show, or set, the fallback browser. |
| `browsers [--json]` | List installed browsers. |
| `--help`, `-h` | Show the usage summary. |

`activate --fallback <desktop-id>` picks a different browser to fall back
to, or sets one when `activate` can't record a current default; without it,
`activate` keeps the fallback you already picked, recording your current
default browser only the first time, when none is recorded yet. `deactivate`
only restores that default — it leaves `rules.json` and `fallback` on disk, so
reactivating later picks up where you left off. `status` shows the fallback
browser, whether `rules.json` is present and how many rules it holds, and
the last few lines of the routing log, which `omarchy-switchyard` keeps at
`~/.local/state/omarchy-switchyard/log`, capped at 200 lines; each line
holds the time, the clicked link's host, the target it opened and the
reason, never the full link (a query string can carry a magic-login token).

## Settings panel

A summoned panel inside `omarchy-shell` shows whether Switchyard is active,
with a switch to turn it on or off, and names the browser unmatched links
open in right now. A "Fallback browser" dropdown picks the browser
unmatched links open in while Switchyard is active. While it is inactive
the panel shows your OS default instead; turning Switchyard on keeps the
fallback you already picked, recording your OS default only the first
time, when no fallback has been set yet. Below it is your rules list,
each rule with icon buttons to edit or
remove it (removing asks you to confirm first). One add row — a host
field, a target dropdown and an icon button — adds a new rule, or
replaces one after Edit fills the row; "Open rules file" opens
`rules.json` in your editor. The panel never edits `rules.json` itself:
every change runs through the CLI, so the panel and the command line
stay in sync.

Summon it with:

```sh
omarchy-shell shell toggle benviu.switchyard '{}'
```

Add a menu row for it in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"switchyard": {
  "icon": "󰖟",
  "label": "Switchyard",
  "action": "omarchy-shell shell toggle benviu.switchyard '{}'"
}
```

Or bind a free key in `~/.config/hypr/bindings.conf` (pick a combination
that isn't already taken):

```
bindd = SUPER SHIFT, S, Switchyard, exec, omarchy-shell shell toggle benviu.switchyard '{}'
```

## How it works

Switchyard registers itself as your system's default browser, so every
clicked link reaches its handler first. The handler checks the link's host
against your rules and launches the matching browser or web app window;
anything that matches no rule, or any link while `rules.json` is missing or
broken, goes to the fallback browser you set when you ran `activate` — so a
mistake in the rules file sends links to the fallback browser, with a
notification, but never loses one.

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
- Your normal browser may ask to become the default again (Zen and
  Firefox do, on start); turn that check off in its settings, since
  accepting it silently deactivates Switchyard the same way (`status`
  shows it; run `activate` again to take over).
- Each clicked link opens a new web-app window at that link; an
  already-open window for the same site is not reused, because Chromium
  has no way to point an open app window at a new address.
- A browser whose desktop entry runs through a wrapper (`flatpak run ...`,
  `env ...`) can't be launched: Switchyard resolves only the first word of
  `Exec=`, the same limit Omarchy's own launcher has.

## Update and uninstall

```sh
omarchy plugin update benviu.switchyard
```

To uninstall, deactivate first so your default browser is restored, then
remove the plugin:

```sh
omarchy-switchyard deactivate
omarchy plugin remove benviu.switchyard
```

## Development

```sh
make check   # shellcheck, qmllint, bats, and the Omarchy plugin validator
```

Needs `bats`, `shellcheck`, `qmllint`, and an Omarchy install (for
`omarchy plugin validate`).

Tests set `SWITCHYARD_APPLICATIONS_DIRS` so they see only the desktop
entries they create, never the real machine's.

## License

MIT, see [LICENSE](LICENSE).
