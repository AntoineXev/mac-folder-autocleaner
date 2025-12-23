#!/usr/bin/env bash
# CLI orchestration for mac-cleaner.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/ui.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/launchd.sh"
source "$ROOT_DIR/lib/executor.sh"

mc_pretty_routines() {
  local routines_json="$1"
/usr/bin/env python3 - "$routines_json" <<'PY'
import json, time, sys, os
raw = sys.argv[1]
if not raw.strip():
    print("No routines.")
    sys.exit(0)
try:
    routines = json.loads(raw)
except json.JSONDecodeError as e:
    if os.environ.get("MC_DEBUG"):
        print(f"[debug] raw={raw!r} error={e}", file=sys.stderr)
    print("Config unreadable.")
    sys.exit(0)
if os.environ.get("MC_DEBUG"):
    print(f"[debug] parsed_len={len(routines)}", file=sys.stderr)
if not routines:
    print("No routines.")
    sys.exit(0)
def next_run(last_run, interval_days):
    if not last_run:
        return "scheduled"
    try:
        ts = time.strptime(last_run, "%Y-%m-%dT%H:%M:%SZ")
        nxt = time.mktime(ts) + interval_days * 86400
        return time.strftime("%Y-%m-%d", time.gmtime(nxt))
    except Exception:
        return "?"
for r in routines:
    print(f"- {r['id']} | {r['path']} | every {r['interval_days']}d | last: {r.get('last_run') or 'never'} | next: {next_run(r.get('last_run'), r['interval_days'])}")
PY
}

mc_prompt() {
  local message="$1" default="${2:-}"
  local input
  if [[ -n "$default" ]]; then
    read -r -p "$message [$default]: " input
    echo "${input:-$default}"
  else
    read -r -p "$message: " input
    echo "$input"
  fi
}

mc_select_routine() {
  local routines_json; routines_json=$(mc_list_routines)
  local items=()
  while IFS= read -r line; do
    items+=("$line")
  done < <(/usr/bin/env python3 - "$routines_json" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for item in r:
    print(f"{item['id']} | {item['path']} | {item['interval_days']}j")
PY
)
  if [[ ${#items[@]} -eq 0 ]]; then
    mc_warn "No routines."
    return 1
  fi
  mc_info "Select a routine (Enter to confirm, q to cancel)"
  set +e
  mc_menu "Routines" "${items[@]}"
  local choice=$?
  set -e
  return "$choice"
}

mc_add_flow() {
  mc_header "New routine"
  local path interval
  path=$(mc_prompt "Folder path to clean (ex: ~/Screenshots)")
  interval=$(mc_prompt "Interval in days" "7")
  if [[ -z "$path" || -z "$interval" ]]; then
    mc_warn "Missing inputs."
    return
  fi
  local id
  id=$(mc_add_routine "$path" "$interval")
  mc_write_plist "$id" "$interval" "$ROOT_DIR"
  mc_load_plist "$id"
  mc_success "Routine added: $id -> $path (every ${interval}d)"
}

mc_list_flow() {
  mc_header "Routines"
  local raw
  raw=$(mc_list_routines)
  if [[ -n "${MC_DEBUG:-}" ]]; then
    printf "[debug] mc_list_routines raw=%s\n" "$raw" >&2
  fi
  mc_pretty_routines "$raw"
}

mc_edit_flow() {
  mc_warn "Edit is disabled for now."
}

mc_delete_flow() {
  local routines_json; routines_json=$(mc_list_routines)
  local ids=()
  while IFS= read -r line; do
    ids+=("$line")
  done < <(/usr/bin/env python3 - "$routines_json" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for item in r:
    print(item["id"])
PY
)
  if [[ ${#ids[@]} -eq 0 ]]; then
    mc_warn "No routines."
    return
  fi
  local menu_items=()
  while IFS= read -r line; do
    menu_items+=("$line")
  done < <(/usr/bin/env python3 - "$routines_json" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for item in r:
    print(f"{item['id']} | {item['path']} | every {item['interval_days']}d")
PY
)
  mc_info "Choose a routine to delete"
  set +e
  mc_menu "Delete" "${menu_items[@]}"
  local choice=$?
  set -e
  if [[ $choice -eq 255 ]]; then
    mc_warn "Cancelled."
    return
  fi
  local id="${ids[$choice]}"
  read -r -p "Confirm deletion of $id ? (y/N) " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    mc_unload_plist "$id"
    mc_delete_routine "$id"
    mc_success "Routine deleted: $id"
  else
    mc_warn "Cancelled."
  fi
}

mc_execute_flow() {
  local routines_json; routines_json=$(mc_list_routines)
  local ids=()
  while IFS= read -r line; do
    ids+=("$line")
  done < <(/usr/bin/env python3 - "$routines_json" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for item in r:
    print(item["id"])
PY
)
  if [[ ${#ids[@]} -eq 0 ]]; then
    mc_warn "No routines."
    return
  fi
  local menu_items=()
  while IFS= read -r line; do
    menu_items+=("$line")
  done < <(/usr/bin/env python3 - "$routines_json" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for item in r:
    print(f"{item['id']} | {item['path']} | every {item['interval_days']}d")
PY
)
  mc_info "Choose a routine to run"
  set +e
  mc_menu "Run" "${menu_items[@]}"
  local choice=$?
  set -e
  if [[ $choice -eq 255 ]]; then
    mc_warn "Cancelled."
    return
  fi
  local id="${ids[$choice]}"
  read -r -p "Dry-run ? (y/N) " dry
  if [[ "$dry" =~ ^[Yy]$ ]]; then
    mc_clean_directory "$id" "true"
  else
    mc_clean_directory "$id" "false"
  fi
}

mc_main_menu() {
  mc_header "mac-cleaner"
  mc_info "Use ↑/↓ or j/k, Enter to confirm, q to quit."
  local options=("Add routine" "List routines" "Delete routine" "Run now" "Quit")
  while true; do
    set +e
    mc_menu "Choose an action" "${options[@]}"
    local choice=$?
    set -e
    case "$choice" in
      0) mc_add_flow;;
      1) mc_list_flow;;
      2) mc_delete_flow;;
      3) mc_execute_flow;;
      4|255) mc_info "Bye"; break;;
    esac
    printf "\n"
  done
}

