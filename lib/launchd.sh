#!/usr/bin/env bash
# launchd helpers for mac-cleaner routines.
set -euo pipefail

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL_PREFIX="com.maccleaner"

mc_plist_path() {
  local id="$1"
  printf "%s/%s.%s.plist" "$LAUNCH_AGENTS_DIR" "$LABEL_PREFIX" "$id"
}

mc_write_plist() {
  local id="$1" interval_days="$2" root_dir="$3"
  mkdir -p "$LAUNCH_AGENTS_DIR"
  local plist; plist=$(mc_plist_path "$id")
  local seconds=$(( interval_days * 86400 ))
  cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL_PREFIX.$id</string>
  <key>ProgramArguments</key>
  <array>
    <string>$root_dir/bin/mc</string>
    <string>run</string>
    <string>--id</string>
    <string>$id</string>
  </array>
  <key>StartInterval</key><integer>$seconds</integer>
  <key>StandardOutPath</key><string>$(mc_logs_dir)/$id.out.log</string>
  <key>StandardErrorPath</key><string>$(mc_logs_dir)/$id.err.log</string>
</dict>
</plist>
EOF
}

mc_load_plist() {
  local id="$1"
  local plist; plist=$(mc_plist_path "$id")
  launchctl unload -w "$plist" >/dev/null 2>&1 || true
  launchctl load -w "$plist"
}

mc_unload_plist() {
  local id="$1"
  local plist; plist=$(mc_plist_path "$id")
  if [[ -f "$plist" ]]; then
    launchctl unload -w "$plist" >/dev/null 2>&1 || true
    rm -f "$plist"
  fi
}

