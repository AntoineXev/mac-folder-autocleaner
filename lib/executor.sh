#!/usr/bin/env bash
# Cleaning logic for routines.
set -euo pipefail

mc_parse_field() {
  local json="$1" key="$2"
  /usr/bin/env python3 -c "$(cat <<'PY'
import json, sys, os

key = sys.argv[1]
raw = sys.stdin.read()
if not raw.strip():
    if os.environ.get("MC_DEBUG"):
        print("[debug] mc_parse_field: empty input", file=sys.stderr)
    sys.exit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError as e:
    if os.environ.get("MC_DEBUG"):
        print(f"[debug] mc_parse_field: decode error: {e} raw={raw!r}", file=sys.stderr)
    sys.exit(0)
val = data.get(key)
if isinstance(val, bool):
    print("true" if val else "false")
elif val is None:
    print("")
else:
    print(val)
PY
)" "$key" <<<"$json"
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
  if [[ -z "$path" || -z "$interval" ]]; then
    mc_error "Routine $id has an invalid config (empty path or interval)."
    return 1
  fi

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
    local updated="" next_run=""
    mc_mark_run "$id"
    updated=$(mc_get_routine "$id") || true
    if [[ -n "$updated" ]]; then
      next_run=$(mc_parse_field "$updated" next_run)
    fi
    if [[ -n "$next_run" ]]; then
      mc_success "Cleanup OK for $path (every ${interval}d). Next: $next_run"
    else
      mc_success "Cleanup OK for $path (every ${interval}d)"
    fi
  else
    mc_info "Dry-run done for $path"
  fi
}

