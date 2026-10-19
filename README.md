# Switchyard

Switchyard is an Omarchy shell plugin: click a link to a site you've chosen
and it opens as a web app, in its own Chromium window with no address bar
or tabs, the way an installed Omarchy web app does (`*.youtube.com → web
app`). Click any other link and it opens in your usual browser instead.
Sending a chosen site to a different browser, rather than opening it as a
web app, is the other thing Switchyard does — handy if you run a
non-Chromium browser as your default (Zen, Firefox, ...) but still need a
site, or a Chromium-only web app, to run in Chromium. All of this happens
without you ever seeing a picker.

## Install

```sh
omarchy plugin add https://github.com/klipa-dev/omarchy-switchyard.git --enable
~/.config/omarchy/plugins/benviu.switchyard/bin/omarchy-switchyard activate
```

Optionally, put the CLI on your `PATH` so you can run it as just
`omarchy-switchyard`:

```sh
ln -s ~/.config/omarchy/plugins/benviu.switchyard/bin/omarchy-switchyard ~/.local/bin/omarchy-switchyard
```

## Rules

Switchyard reads `~/.config/omarchy-switchyard/rules.json`. Copy
`rules.example.json` there and edit it:

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

Each clicked link is matched against `rules` in order; the first rule whose
`host` fits wins. `host` is the link's host, lowercased, with any
`user:pass@`, port, path and query removed; only `http` and `https` links
have a host, so anything else (`mailto:`, a bare word, ...) always falls
through. A host covers the site and all its subdomains: `basecamp.com` and
`*.basecamp.com` are the same rule, and both match `basecamp.com`,
`www.basecamp.com` and any other subdomain; there's no way to match a host
and exclude its subdomains.

`target` is the word `webapp`, which opens the link as a browser window with
no address bar or tabs, the way an installed web app does, or a desktop id
(`chromium.desktop`, `zen.desktop`, ...), which opens the link in that
browser's ordinary window instead. The browser behind `webapp` is whichever
Chromium-family browser Switchyard resolves itself: the fallback browser
below, if it is Chromium-family, otherwise `chromium.desktop` — not
necessarily the fallback browser itself.

A link that matches no rule goes to the fallback browser: the single
desktop id in `~/.config/omarchy-switchyard/fallback`, which `activate`
writes from your current default browser (so a broken or missing
`rules.json` can never lose it; a missing or invalid `rules.json` just
means every link goes to the fallback, with a notification if the file is
invalid). A rule whose browser isn't installed behaves the same way: the
link opens in the fallback browser instead, with a notification.

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
`rules add` normalises whatever you type to the canonical `*.<host>` form —
lowercased, with any scheme, `user:pass@`, port, path and query stripped,
and a leading `www.` dropped — so `youtube.com`, `www.youtube.com`,
`*.www.youtube.com` and that URL all save as `*.youtube.com`. It also
checks that `<target>` is `webapp` or a desktop id that actually resolves
to an installed application, before writing. Each command prints what it
did:

```
Rule added: *.youtube.com → webapp
Rule changed: *.youtube.com → webapp (replaces www.youtube.com → chromium.desktop)
Rule changed: *.youtube.com → webapp (replaces *.youtube.com → webapp, www.youtube.com → chromium.desktop)
Rule unchanged: *.youtube.com → webapp
Rule removed: *.youtube.com
```

The parenthetical lists, in full and in the order they appeared in the
file, every existing rule the write replaced (`<host> → <target>`, comma
separated if there was more than one — a leftover file can hold several
entries that all normalise to the same host). `Rule unchanged` only fires
when exactly one existing rule already matched both the canonical host and
the target you asked for; anything else that touches an existing rule,
including a host-form-only rewrite, is a `Rule changed`.

When the host you typed isn't already in the canonical form, `rules add`
prints a second line: `Saved as *.youtube.com, which matches youtube.com
and all its subdomains.` Adding a rule for a host that already has one
(typed any way that normalises the same) replaces it in place; `rules
remove` compares the same way and fails if there is no rule for that host.
`browsers` lists every installed browser's desktop id and name, which is
useful for picking a `<target>` or a fallback. None of these commands touch
your rules file if the host, target or desktop id is invalid, and none of
them ever hand-edit `rules.json`: each writes the whole file atomically. If
`rules.json` itself is invalid JSON, every command that would otherwise
write to it fails instead, telling you the file to fix by hand.

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

## Settings panel

A summoned panel inside `omarchy-shell` shows the same status the CLI does
(active or not, the fallback browser) and your configured rules, each as
`<host> → <target>` (a `webapp` target shows as "Web app window"). An
"Activate" / "Deactivate" button toggles the plugin, and "Open rules file"
opens `rules.json` in your editor. You can also add, edit and remove rules
and pick the fallback browser from the panel itself, each from a dropdown
of your installed browsers; "Edit" fills in a rule's host and target so
"Add" can replace it, and "Remove" asks you to confirm first. The panel
never edits `rules.json` itself; every change runs through the CLI, so the
panel and the command line stay in sync.

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

## Status and log

```sh
omarchy-switchyard status
```

prints whether Switchyard is the current default browser, the recorded
fallback, whether `rules.json` is present and how many rules it has, and
the last few lines of the routing log. Every routing decision — matched
rule or fallback, and the browser it launched — is appended to
`~/.local/state/omarchy-switchyard/log` (the last 200 lines are kept).
Add `--json` for the same facts as a single JSON object, meant for
scripts and the settings panel rather than reading by eye.

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

## Development

```sh
make check   # shellcheck, qmllint, bats, and the Omarchy plugin validator
```

Needs `bats`, `shellcheck`, `qmllint`, and an Omarchy install (for
`omarchy plugin validate`).

Tests set `SWITCHYARD_APPLICATIONS_DIRS` so they see only the desktop
entries they create, never the real machine's.
