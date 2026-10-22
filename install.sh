#!/usr/bin/env bash
# Installiert Skript, systemd-Units und das Quickshell-Plugin (Symlink).
set -e
D="$(cd "$(dirname "$0")" && pwd)"
install -Dm755 "$D/unraid-backup" ~/.local/bin/unraid-backup
install -Dm644 "$D"/systemd/unraid-backup.{service,timer} -t ~/.config/systemd/user/
mkdir -p ~/.config/unraid-backup ~/.config/omarchy/plugins
[ -f ~/.config/unraid-backup/config ] || cp "$D/config.example" ~/.config/unraid-backup/config
ln -sfn "$D/plugin" ~/.config/omarchy/plugins/hendkai.unraid-backup
systemctl --user daemon-reload && systemctl --user enable --now unraid-backup.timer
echo "Fertig. HOST/BASE in ~/.config/unraid-backup/config prüfen, Widget: omarchy plugin enable hendkai.unraid-backup"
