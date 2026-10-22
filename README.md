# omarchy-unraid-backup

rsync backup of `$HOME` to an Unraid (or any SSH) host, plus an Omarchy bar widget showing its status.

- `unraid-backup` — mirror into `BASE/current`, changed/deleted files into `BASE/archive/<date>` (pruned after `KEEP_DAYS`). Writes `~/.local/state/unraid-backup/status.json`.
- `plugin/` — Quickshell bar widget `hendkai.unraid-backup`: cloud icon + age of last good backup; red when failed/overdue; left click = back up now, right click = log.
- `systemd/` — daily user timer.

Install: `./install.sh`, edit `~/.config/unraid-backup/config` (and `excludes`), then `omarchy plugin enable hendkai.unraid-backup`.
Requires key-based SSH to the host and `rsync` on both sides.
