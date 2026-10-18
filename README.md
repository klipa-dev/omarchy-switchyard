# Switchyard

Switchyard is an Omarchy shell plugin that routes each link you click to the
browser you want it in, based on the link's host. Set a handful of host
rules and Switchyard opens Google Meet links in Chromium, a work tool as a
Chromium web app, and everything else in your regular browser, without you
ever seeing a picker.

Status: in development, not yet released.

## Development

```sh
make check   # shellcheck, qmllint, bats, and the Omarchy plugin validator
```

Needs `bats`, `shellcheck`, `qmllint`, and an Omarchy install (for
`omarchy plugin validate`).
