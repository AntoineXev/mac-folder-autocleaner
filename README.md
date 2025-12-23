# mac-cleaner (Mole-style prototype)

Small Bash utility inspired by [Mole](https://github.com/tw93/Mole) to schedule recurring folder cleanups (e.g. `~/Screenshots`).

## Quick install

```bash
chmod +x /Users/antoine/Projects/mac-cleaner/bin/mc
export PATH="/Users/antoine/Projects/mac-cleaner/bin:$PATH"
mc
```

## Commands

- `mc` : interactive menu (↑/↓ or j/k, Enter, q to quit)
- `mc add|list|delete|exec` : direct actions (edit disabled)
- `mc run --id <id> [--dry-run]` : called by launchd

## How it works

- JSON config at `~/.config/maccleaner/routines.json`
- Logs at `~/.config/maccleaner/logs/<id>.run.log`
- Each routine creates a user LaunchAgent `~/Library/LaunchAgents/com.maccleaner.<id>.plist` with `StartInterval` (days → seconds) calling `mc run --id <id>`.
- Safety: rejects empty path, `/`, `$HOME`, `/Users`.

## Typical flow

1. `mc add` → enter folder + interval (days) → plist generated + `launchctl load -w`.
2. `mc list` → shows path, interval, last_run, next ETA.
3. `mc exec` → run immediately with optional dry-run.
4. `mc delete` → unloads and removes the routine.

## Manual tests

- Add a routine on a test folder, dry-run then real run.
- Check plist presence/load (`launchctl list | grep maccleaner`).
- Delete the routine and ensure the plist is gone.

