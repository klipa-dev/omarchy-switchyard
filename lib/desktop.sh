# shellcheck shell=bash
# lib/desktop.sh — the desktop-entry search order every lookup in this repo
# uses. Sourced, not executed.

# switchyard_applications_dirs — prints the desktop-entry search
# directories, one per line, in search order:
# ${XDG_DATA_HOME:-$HOME/.local/share}/applications, then
# $HOME/.nix-profile/share/applications, then /usr/share/applications.
# When SWITCHYARD_APPLICATIONS_DIRS is set and non-empty, prints its
# colon-separated entries instead (empty entries skipped), so a test can
# see only the fake desktop entries it creates. Unset, this is
# byte-for-byte the three directories above.
switchyard_applications_dirs() {
  if [[ -n ${SWITCHYARD_APPLICATIONS_DIRS:-} ]]; then
    local dir
    local -a dirs
    IFS=: read -ra dirs <<<"$SWITCHYARD_APPLICATIONS_DIRS"
    for dir in "${dirs[@]}"; do
      [[ -n $dir ]] && printf '%s\n' "$dir"
    done
    return 0
  fi

  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    "$HOME/.nix-profile/share/applications" \
    "/usr/share/applications"
}
