#!/usr/bin/env bash
# Offline smoke test. Self-isolating: re-execs itself under a private session bus with
# HOME at a throwaway directory. This ordering matters — the dconf service inherits the
# bus daemon's environment, so exporting HOME inside the child would still write to the
# real user database.
#   bash tests/smoke.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${SMOKE_T:-}" ]]; then
  SMOKE_T="$(mktemp -d)"
  export SMOKE_T HOME="$SMOKE_T" XDG_CONFIG_HOME="$SMOKE_T/.config" XDG_DATA_HOME="$SMOKE_T/.local/share"
  mkdir -p "$HOME"
  exec dbus-run-session -- bash "$0" "$@" 2>"$SMOKE_T/bus.log"
fi

T="$SMOKE_T"
trap 'rm -rf "$T"' EXIT

if ! "$REPO/install.sh" --offline >"$T/run1.log" 2>&1; then
  cat "$T/run1.log"; exit 1
fi

fail=0
t() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi; }

t "gtk3 theme copied"      test -d "$HOME/.themes/Flat-Remix-GTK-Blue-Dark/gtk-3.0"
t "gtk4 theme css copied"  test -f "$HOME/.themes/Flat-Remix-GTK-Blue-Dark/gtk-4.0/gtk.css"
t "shell theme copied"     test -d "$HOME/.themes/WhiteSur-Dark/gnome-shell"
t "gtk4 css is symlink"    test -L "$HOME/.config/gtk-4.0/gtk.css"
t "gtk4 css resolves"      test -r "$HOME/.config/gtk-4.0/gtk.css"
t "wallpaper installed"    cmp -s "$REPO/gnome/wallpaper.png" "$HOME/.config/background"
t "kitty include present"  test -f "$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
t "fish prompt committed"  grep -q multiverse-neon "$HOME/.config/fish/config.fish"
t "gtk theme applied"      bash -c "dconf read /org/gnome/desktop/interface/gtk-theme | grep -q Flat-Remix"
t "shell theme data captured" grep -q WhiteSur-Dark "$REPO/gnome/dconf/extensions/user-theme@gnome-shell-extensions.gcampax.github.com.ini"
# Guards the failure mode where a wrong settings path dumps 0 bytes and ships an empty file.
t "ext settings captured"  bash -c 'for f in "$1"/gnome/dconf/extensions/*.ini; do [ -s "$f" ] && grep -q "^\[/\]" "$f" || exit 1; done' _ "$REPO"
t "skips settings for absent extensions" bash -c '[[ -z "$(dconf read /org/gnome/shell/extensions/user-theme/name)" ]]'
t "no stale ext ids"       bash -c '! dconf read /org/gnome/shell/enabled-extensions | grep -qE "simplenetspeed|search-light|netspeed@"'

# idempotency
if "$REPO/install.sh" --offline >"$T/run2.log" 2>&1; then
  echo "ok   second run succeeds"
else
  echo "FAIL second run"; tail -20 "$T/run2.log"; fail=1
fi

exit "$fail"
