#!/usr/bin/env bash
# Fedora 44 / GNOME 50 personal UI setup. Idempotent; safe to re-run.
# Usage: ./install.sh [--offline]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE=0
[[ "${1:-}" == "--offline" ]] && OFFLINE=1

GTK_THEME="Flat-Remix-GTK-Blue-Dark"
ICON_THEME="Flat-Remix-Blue-Dark"
SHELL_THEME="WhiteSur-Dark"
ICONS_TAG="20251119"
ICONS_URL="https://github.com/daniruiz/flat-remix/archive/refs/tags/${ICONS_TAG}.tar.gz"
FONT_TAG="v3.5.1"
FONT_BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_TAG}"
# archive-name:font-family-used-by-ghostty-and-kitty
FONTS=("FantasqueSansMono:FantasqueSansM Nerd Font Mono" "FiraCode:FiraCode Nerd Font Mono")
GHOSTTY_REPO="https://github.com/Aditaya08/ghostty-config.git"
STATE="$HOME/.local/state/fedora-gnome-dotfiles"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

backup_state() {
  say "Backing up current dconf and terminal config"
  mkdir -p "$STATE"
  dconf dump /org/gnome/ > "$STATE/dconf-before-$(date +%Y%m%d-%H%M%S).ini"
  if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    cp "$HOME/.config/fish/config.fish" "$STATE/fish-config.bak"
  fi
}

# No rm -rf: copying over keeps unrelated variants and cannot destroy anything the user added.
install_themes() {
  say "Installing committed themes into ~/.themes"
  mkdir -p "$HOME/.themes"
  cp -a "$REPO/themes/$GTK_THEME" "$HOME/.themes/"
  cp -a "$REPO/themes/$SHELL_THEME" "$HOME/.themes/"
}

install_icons() {
  if [[ -d "$HOME/.icons/$ICON_THEME" ]]; then
    say "Icon theme already present"; return 0
  fi
  if [[ $OFFLINE -eq 1 ]]; then warn "offline: skipping icon theme"; return 0; fi
  say "Downloading Flat-Remix icons ($ICONS_TAG)"
  local tmp; tmp="$(mktemp -d)"
  # Archive members are "flat-remix-<tag>/Flat-Remix-Blue-Dark/...", so match with a
  # wildcard and strip the tag directory; only the one variant is written to disk.
  curl -fsSL "$ICONS_URL" \
    | tar -xz -C "$tmp" --strip-components=1 --wildcards "*/${ICON_THEME}/*"
  mkdir -p "$HOME/.icons"
  cp -a "$tmp/$ICON_THEME" "$HOME/.icons/"
  rm -rf "$tmp"
}

install_font() {
  local entry archive family tmp
  for entry in "${FONTS[@]}"; do
    archive="${entry%%:*}"
    family="${entry##*:}"
    if fc-list 2>/dev/null | grep -q "$family"; then
      say "Font already present: $family"; continue
    fi
    if [[ $OFFLINE -eq 1 ]]; then warn "offline: skipping font $family"; continue; fi
    say "Installing $family"
    tmp="$(mktemp -d)"
    curl -fsSL "${FONT_BASE}/${archive}.tar.xz" | tar -xJ -C "$tmp"
    mkdir -p "$HOME/.local/share/fonts"
    cp -a "$tmp"/*.ttf "$HOME/.local/share/fonts/"
    rm -rf "$tmp"
  done
  command -v fc-cache >/dev/null && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
}

# This is what makes GTK4/libadwaita apps follow the theme; gtk-theme-name alone
# is ignored by libadwaita.
link_gtk() {
  say "Linking GTK4 theme CSS and installing GTK settings"
  mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-3.0"
  ln -sfn "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk.css"      "$HOME/.config/gtk-4.0/gtk.css"
  ln -sfn "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
  cp "$REPO/gnome/gtk-4.0-settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
  cp "$REPO/gnome/gtk-3.0-settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
}

shell_version() { gnome-shell --version | awk '{print $3}' | cut -d. -f1; }

install_extensions() {
  say "Installing GNOME extensions for shell $(shell_version)"
  local uuid url tmp
  local have; have="$(gnome-extensions list 2>/dev/null || true)"
  while read -r uuid; do
    [[ -z "$uuid" || "$uuid" == \#* ]] && continue
    if grep -qx "$uuid" <<<"$have"; then
      say "  present: $uuid"; continue
    fi
    if [[ $OFFLINE -eq 1 ]]; then warn "offline: skipping $uuid"; continue; fi
    url="$(curl -fsSL \
      "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=$(shell_version)" \
      | jq -r '.download_url // empty')"
    if [[ -z "$url" ]]; then warn "no build for GNOME $(shell_version): $uuid"; continue; fi
    tmp="$(mktemp -d)"
    curl -fsSL "https://extensions.gnome.org${url}" -o "$tmp/ext.zip"
    gnome-extensions install --force "$tmp/ext.zip"
    rm -rf "$tmp"
    say "  installed: $uuid"
  done < "$REPO/gnome/extensions.list"
}

# dconf load merges: only keys present in the file change. The enabled list is built
# at install time from what actually installed, so a failed extension never becomes
# an error badge in the Extensions app.
load_dconf() {
  say "Applying dconf settings"
  local d="$REPO/gnome/dconf" uuid active=() list
  dconf load /org/gnome/desktop/interface/      < "$d/interface.ini"
  dconf load /org/gnome/desktop/background/     < "$d/background.ini"
  dconf load /org/gnome/desktop/wm/preferences/ < "$d/wm-preferences.ini"
  dconf load /org/gnome/desktop/app-folders/    < "$d/app-folders.ini"

  for f in "$d"/extensions/*.ini; do
    uuid="$(basename "$f" .ini)"
    if gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
      dconf load "/org/gnome/shell/extensions/$uuid/" < "$f"
    else
      warn "not installed, skipping settings: $uuid"
    fi
  done

  while read -r uuid; do
    [[ -z "$uuid" || "$uuid" == \#* ]] && continue
    gnome-extensions list 2>/dev/null | grep -qx "$uuid" && active+=("'$uuid'")
  done < "$REPO/gnome/extensions.list"
  list="[$(IFS=,; echo "${active[*]}")]"
  { echo "enabled-extensions=$list"; cat "$d/shell.ini"; } | dconf load /org/gnome/shell/
}

set_wallpaper() {
  say "Setting wallpaper"
  mkdir -p "$HOME/.config"
  cp "$REPO/gnome/wallpaper.png" "$HOME/.config/background"
  gsettings set org.gnome.desktop.background picture-uri      "file://$HOME/.config/background"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/.config/background"
}

flatpak_bridge() {
  command -v flatpak >/dev/null || { warn "flatpak not installed, skipping"; return 0; }
  say "Applying flatpak override"
  flatpak override --user --filesystem="$HOME/.themes" --filesystem="$HOME/.icons"
  flatpak override --user --env=ICON_THEME="$ICON_THEME"
  # Deliberate: GTK_THEME does not reach any installed flatpak (GTK4/Qt/Electron).
  flatpak override --user --unset-env=GTK_THEME 2>/dev/null || true
}

install_terminals() {
  say "Setting up kitty, fish and ghostty"
  mkdir -p "$HOME/.config/kitty/kitty-themes" "$HOME/.config/fish"
  cp "$REPO/terminal/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
  cp "$REPO/terminal/kitty/00-Default.conf" "$REPO/terminal/kitty/01-Wallust.conf" \
     "$HOME/.config/kitty/kitty-themes/"
  cp "$REPO/terminal/fish/multiverse-neon.omp.json" "$HOME/.config/fish/"
  cp "$REPO/terminal/fish/config.fish" "$HOME/.config/fish/config.fish"

  if ! command -v oh-my-posh >/dev/null; then
    if [[ $OFFLINE -eq 1 ]]; then
      warn "offline: skipping oh-my-posh"
    else
      curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
    fi
  fi

  if [[ -d "$HOME/.config/ghostty/.git" ]]; then
    git -C "$HOME/.config/ghostty" pull --ff-only || warn "ghostty config not updated"
  elif [[ $OFFLINE -eq 1 ]]; then warn "offline: skipping ghostty config"
  else
    git clone "$GHOSTTY_REPO" "$HOME/.config/ghostty"
  fi
}

summary() {
  local got=0 want=0 u
  while read -r u; do
    [[ -z "$u" || "$u" == \#* ]] && continue
    want=$((want+1))
    gnome-extensions list 2>/dev/null | grep -qx "$u" && got=$((got+1))
  done < "$REPO/gnome/extensions.list"
  say "Done: $got/$want extensions present, themes in ~/.themes, settings loaded"
  [[ -d "$HOME/.local/share/fonts" ]] || warn "nerd font missing — terminal will use a fallback"
  say "Log out and back in: extension settings and the shell theme only apply on a new session"
  [[ -d "$STATE" ]] && say "Previous dconf snapshot: $STATE"
}

main() {
  need dconf; need gsettings; need gnome-extensions; need jq; need curl
  backup_state
  install_themes
  install_icons
  install_font
  link_gtk
  install_extensions
  load_dconf
  set_wallpaper
  flatpak_bridge
  install_terminals
  summary
}

main "$@"
