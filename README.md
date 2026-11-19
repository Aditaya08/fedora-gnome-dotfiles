# fedora-gnome-dotfiles

My Fedora 44 / GNOME 50 (Wayland) desktop, reproducible from one script.

## What this restores

- GTK theme `Flat-Remix-GTK-Blue-Dark`, icon theme `Flat-Remix-Blue-Dark`, shell theme `WhiteSur-Dark`
- GTK3/GTK4 settings and the `~/.config/gtk-4.0/gtk.css` symlink that makes libadwaita apps follow the theme
- Six GNOME extensions, with their settings, from extensions.gnome.org
- dconf: interface, background, window-manager preferences, app folders, favourite apps
- Wallpaper, kitty config, fish + oh-my-posh prompt, and a clone of my ghostty config

## What it does not touch

- Qt/Kvantum apps, app-level preferences, fish variables beyond the terminal setup
- Flatpak app theming beyond icons: GTK4, Qt and Electron flatpaks carry their own look
- `search-light` (no GNOME 50 build) and two stale extension ids from an older setup

## Install

    git clone https://github.com/Aditaya08/fedora-gnome-dotfiles.git
    cd fedora-gnome-dotfiles
    ./install.sh          # add --offline to skip the icon theme, fonts, extensions and ghostty clone

Then log out and back in. Extension settings and the shell theme only load in a new session.

Before changing anything, `install.sh` writes `dconf dump /org/gnome/` to `~/.local/state/fedora-gnome-dotfiles/`. `dconf load` merges, so only the keys this repo captured are replaced.

## Updating after you change your desktop

    ./export.sh     # re-dump dconf, copy terminal configs and wallpaper
    git diff        # review what changed
    git commit -am "chore: sync"

`export.sh` also reports drift for the two committed theme subsets, and reads each extension's settings path from its own schema — extensions pick those paths themselves, so they do not always match the extension's uuid.

## Requirements

Fedora 44, GNOME Shell 50, and `dnf`. `install.sh` checks for `git`, `curl`, `jq`, `dconf` and `gnome-extensions` and installs the missing ones with `sudo dnf install` (`gnome-extensions` comes from `gnome-shell`). The FantasqueSansMono and FiraCode Nerd Fonts, the icon theme and the extensions are downloaded separately at install time.

Terminals are not installed by the script; use `dnf install -y kitty ghostty fish gnome-shell-extensions` if you want them.

## Credits

Theme and font attributions: `THIRD-PARTY.md`.
