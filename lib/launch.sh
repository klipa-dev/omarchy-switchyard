# shellcheck shell=bash
# lib/launch.sh — the only code that starts a browser. Sourced, not
# executed. Honours SWITCHYARD_DRY_RUN=1 (set by the handler's --dry-run).

fail() {
  echo "switchyard: $*" >&2
  exit 1
}

# Exit status switchyard_launch returns when the resolved desktop id has no
# desktop entry (distinct from fail's 1), so the handler can retry with the
# fallback browser instead of failing outright. Named so the sentinel isn't
# a bare literal in both this file and bin/omarchy-switchyard-open.
SWITCHYARD_MISSING_TARGET=3

# _switchyard_resolve_exec <desktop-id> — prints the first word of the
# entry's Exec=, in the same search order lib/router.sh resolves a
# fallback candidate from.
_switchyard_resolve_exec() {
  local id=$1 dir path line
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    "$HOME/.nix-profile/share/applications" \
    "/usr/share/applications"; do
    path="$dir/$id"
    if [[ -f $path ]]; then
      line=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$path" | head -1)
      if [[ -n $line ]]; then
        printf '%s\n' "$line"
        return 0
      fi
    fi
  done
  return 1
}

# switchyard_webapp_browser <fallback-file> — pure: prints the desktop id
# of the Chromium-family browser a "webapp" target opens in. The fallback
# file's first line when it names one (the omarchy-launch-webapp list),
# else chromium.desktop.
switchyard_webapp_browser() {
  local fallback_file=$1 fallback=""
  if [[ -f $fallback_file ]]; then
    IFS= read -r fallback <"$fallback_file" || true
  fi
  case $fallback in
  chromium.desktop | google-chrome* | microsoft-edge* | brave* | opera* | vivaldi* | helium*)
    printf '%s\n' "$fallback"
    ;;
  *)
    printf '%s\n' "chromium.desktop"
    ;;
  esac
}

# switchyard_launch <target> <url> <fallback-file> [browser-flags...] —
# launches <target> (a desktop id, or "webapp") with <url>. A "--private"
# flag among the browser flags is translated to the resolved browser's own
# private-window flag (dropped for "webapp"). Prints the command line
# instead of running it when SWITCHYARD_DRY_RUN=1. Returns
# $SWITCHYARD_MISSING_TARGET when the resolved desktop id has no desktop
# entry, so the handler can retry with the fallback browser instead of
# failing outright.
switchyard_launch() {
  local target=$1 url=$2 fallback_file=$3
  shift 3

  local want_private=0
  local other_flags=()
  local f
  for f in "$@"; do
    if [[ $f == "--private" ]]; then
      want_private=1
    else
      other_flags+=("$f")
    fi
  done

  local desktop_id app_flag=""
  if [[ $target == "webapp" ]]; then
    desktop_id=$(switchyard_webapp_browser "$fallback_file")
    app_flag="--app=$url"
    url=""
    want_private=0
    other_flags=()
  else
    desktop_id=$target
  fi

  local exec_path
  if ! exec_path=$(_switchyard_resolve_exec "$desktop_id"); then
    echo "switchyard: no desktop entry for $desktop_id" >&2
    return "$SWITCHYARD_MISSING_TARGET"
  fi

  local private_flag=""
  if ((want_private)); then
    if "$exec_path" --help 2>/dev/null | grep -q MOZ_LOG; then
      private_flag="--private-window"
    elif [[ $exec_path =~ edge ]]; then
      private_flag="--inprivate"
    else
      private_flag="--incognito"
    fi
  fi

  local cmd=(setsid uwsm-app -- "$exec_path")
  [[ -n $app_flag ]] && cmd+=("$app_flag")
  [[ -n $private_flag ]] && cmd+=("$private_flag")
  cmd+=("${other_flags[@]}")
  [[ -n $url ]] && cmd+=("$url")

  if [[ ${SWITCHYARD_DRY_RUN:-0} == 1 ]]; then
    local out="" arg
    for arg in "${cmd[@]}"; do
      out+=$(printf '%q ' "$arg")
    done
    printf '%s\n' "${out% }"
    return 0
  fi

  "${cmd[@]}"
}
