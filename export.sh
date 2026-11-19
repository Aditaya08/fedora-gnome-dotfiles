#!/usr/bin/env bash
# Re-capture this machine's GNOME UI state into the repo. Run from anywhere.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$REPO/gnome/dconf"
mkdir -p "$D/extensions"

dconf dump /org/gnome/desktop/interface/      > "$D/interface.ini"
dconf dump /org/gnome/desktop/background/     > "$D/background.ini"
dconf dump /org/gnome/desktop/wm/preferences/ > "$D/wm-preferences.ini"
dconf dump /org/gnome/desktop/app-folders/    > "$D/app-folders.ini"

# Only keys this repo owns. app-picker-layout and welcome-dialog-last-shown-version
# are machine-specific and are deliberately not captured.
{
  echo "favorite-apps=$(dconf read /org/gnome/shell/favorite-apps)"
  echo "disabled-extensions=$(dconf read /org/gnome/shell/disabled-extensions)"
} > "$D/shell.ini"

while read -r uuid; do
  [[ -z "$uuid" || "$uuid" == \#* ]] && continue
  dconf dump "/org/gnome/shell/extensions/$uuid/" > "$D/extensions/$uuid.ini"
done < "$REPO/gnome/extensions.list"

cp "$HOME/.config/background"                         "$REPO/gnome/wallpaper.png"
cp "$HOME/.config/gtk-3.0/settings.ini"               "$REPO/gnome/gtk-3.0-settings.ini"
cp "$HOME/.config/gtk-4.0/settings.ini"               "$REPO/gnome/gtk-4.0-settings.ini"
cp "$HOME/.config/kitty/kitty.conf"                   "$REPO/terminal/kitty/kitty.conf"
cp "$HOME/.config/kitty/kitty-themes/00-Default.conf" "$REPO/terminal/kitty/00-Default.conf"
cp "$HOME/.config/kitty/kitty-themes/01-Wallust.conf" "$REPO/terminal/kitty/01-Wallust.conf"
# config.fish is NOT re-copied: after install it points at ~/.config/fish, and the live
# file on a machine still using ~/.poshthemes would revert Task 2 Step 3.
cp "$HOME/.poshthemes/multiverse-neon.omp.json"       "$REPO/terminal/fish/multiverse-neon.omp.json"

# Drift check: only files the repo tracks are compared ("Only in" lines are extras
# installed upstream, e.g. gtk-2.0, and are expected).
for t in Flat-Remix-GTK-Blue-Dark WhiteSur-Dark; do
  diff -r "$REPO/themes/$t" "$HOME/.themes/$t" 2>/dev/null | grep -v '^Only in' || true
done

git -C "$REPO" status --short
