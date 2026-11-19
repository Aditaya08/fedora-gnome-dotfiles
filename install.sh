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
