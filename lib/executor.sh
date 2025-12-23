#!/usr/bin/env bash
# Cleaning logic for routines.
set -euo pipefail

mc_parse_field() {
  local json="$1" key="$2"
  echo "$json" | /usr/bin/env python3 - "$key" <<'PY'
import json, sys
key = sys.argv[1]
data = json.loads(sys.stdin.read())
val = data.get(key)
if isinstance(val, bool):
    print("true" if val else "false")
elif val is None:
    print("")
else:
    print(val)
PY
}

mc_is_safe_path() {
  local p="$1"
  [[ -n "$p" && "$p" != "/" && "$p" != "$HOME" && "$p" != "/Users" ]]
}

mc_clean_directory() {
  local id="$1" dry="$2"
  local routine_json; routine_json=$(mc_get_routine "$id") || {
    mc_error "Routine not found: $id"
    return 1
  }
  local path interval
  path=$(mc_parse_field "$routine_json" path)
  interval=$(mc_parse_field "$routine_json" interval_days)

  local log_file; log_file="$(mc_logs_dir)/$id.run.log"
  mkdir -p "$(dirname "$log_file")"

  {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] start id=$id path=$path dry=$dry"
    if [[ -z "$path" ]]; then
      echo "path empty, abort"
      exit 1
    fi
    if ! mc_is_safe_path "$path"; then
      echo "path not allowed: $path"
      exit 1
    fi
    if [[ ! -d "$path" ]]; then
      echo "path not found: $path"
      exit 1
    fi

    if [[ "$dry" == "true" ]]; then
      echo "dry-run: listing entries"
      find "$path" -mindepth 1 -maxdepth 1 -print
    else
      echo "cleaning..."
      find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
    echo "done"
  } | tee -a "$log_file"

  if [[ "$dry" != "true" ]]; then
    mc_mark_run "$id"
    mc_success "Cleanup OK for $path (every ${interval}d)"
  else
    mc_info "Dry-run done for $path"
  fi
}

