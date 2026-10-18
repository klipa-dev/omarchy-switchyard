# shellcheck shell=bash
# lib/router.sh — pure routing: a URL, the rules file and the fallback file
# yield a target. Launches nothing (lib/launch.sh does that). Sourced, not
# executed.

fail() {
  echo "switchyard: $*" >&2
  exit 1
}

# _switchyard_host <url> — prints the lowercased host of an http(s) URL
# (userinfo, port, path and query stripped), or fails for anything else
# (mailto:, ftp://, a bare word, ...).
_switchyard_host() {
  local url=$1 authority host
  if [[ ! $url =~ ^[Hh][Tt][Tt][Pp][Ss]?:// ]]; then
    return 1
  fi
  authority=${url#*://}
  authority=${authority%%[/?#]*}
  authority=${authority##*@}
  host=${authority%%:*}
  host=${host,,}
  [[ -n $host ]] || return 1
  printf '%s\n' "$host"
}

# _switchyard_host_matches <host> <pattern> — a bare pattern matches only
# itself; "*.example.com" matches example.com and any subdomain.
_switchyard_host_matches() {
  local host=$1 pattern=$2 suffix
  pattern=${pattern,,}
  if [[ $pattern == \*.* ]]; then
    suffix=${pattern#\*.}
    [[ $host == "$suffix" || $host == *".$suffix" ]]
  else
    [[ $host == "$pattern" ]]
  fi
}

# _switchyard_desktop_entry <desktop-id> — prints the path to the desktop
# entry if one resolves, in the same search order lib/launch.sh resolves
# Exec from.
_switchyard_desktop_entry() {
  local id=$1 dir
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    "$HOME/.nix-profile/share/applications" \
    "/usr/share/applications"; do
    if [[ -f "$dir/$id" ]]; then
      printf '%s\n' "$dir/$id"
      return 0
    fi
  done
  return 1
}

# _switchyard_fallback <fallback-file> — the fallback browser's desktop id.
_switchyard_fallback() {
  local fallback_file=$1 fallback=""

  if [[ -f $fallback_file ]]; then
    IFS= read -r fallback <"$fallback_file" || true
    if [[ -n $fallback ]]; then
      printf '%s\n' "$fallback"
      return 0
    fi
  fi

  fallback=$(env -u BROWSER xdg-settings get default-web-browser 2>/dev/null || true)
  if [[ -n $fallback && $fallback != "omarchy-switchyard.desktop" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  local candidate
  for candidate in chromium.desktop firefox.desktop; do
    if _switchyard_desktop_entry "$candidate" >/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  fail "no fallback browser found"
}

# switchyard_route <url> <rules-file> <fallback-file> — prints
# "<target>\t<reason>": "<desktop-id>\trule:<host pattern>" or
# "webapp\trule:<host pattern>" for the first matching rule,
# "<fallback>\tfallback" otherwise. Launches nothing.
switchyard_route() {
  local url=$1 rules_file=$2 fallback_file=$3
  local host
  host=$(_switchyard_host "$url") || host=""

  if [[ -f $rules_file ]]; then
    if ! jq -e '(.rules // null) | type == "array"' "$rules_file" >/dev/null 2>&1; then
      echo "switchyard: rules.json is invalid, using the fallback" >&2
    else
      local idx rhost rtarget
      while IFS=$'\t' read -r idx rhost rtarget; do
        if [[ -z $rhost || -z $rtarget ]]; then
          echo "switchyard: rules.json rule $idx is missing host or target, skipping" >&2
          continue
        fi
        if [[ -n $host ]] && _switchyard_host_matches "$host" "$rhost"; then
          printf '%s\trule:%s\n' "$rtarget" "$rhost"
          return 0
        fi
      done < <(jq -r '.rules | to_entries[] |
        [.key,
         ((.value | objects | .host | strings) // ""),
         ((.value | objects | .target | strings) // "")] |
        @tsv' "$rules_file")
    fi
  fi

  local fallback
  fallback=$(_switchyard_fallback "$fallback_file")
  printf '%s\tfallback\n' "$fallback"
}
