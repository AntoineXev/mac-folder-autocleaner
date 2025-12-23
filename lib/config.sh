#!/usr/bin/env bash
# Config and persistence helpers for mac-cleaner routines.
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}/maccleaner"
CONFIG_FILE="$CONFIG_DIR/routines.json"
LOG_DIR="$CONFIG_DIR/logs"
RUNTIME_DIR="$CONFIG_DIR/runtime"

mc_ensure_config() {
  mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$RUNTIME_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"routines":[]}' >"$CONFIG_FILE"
    return
  fi
  /usr/bin/env python3 - "$CONFIG_FILE" <<'PY'
import json, sys, os
cfg = sys.argv[1]
try:
    with open(cfg) as f:
        data = json.load(f)
    if not isinstance(data, dict) or "routines" not in data or not isinstance(data["routines"], list):
        raise ValueError("bad shape")
except Exception:
    with open(cfg, "w") as f:
        json.dump({"routines": []}, f)
PY
}

mc_config_path() {
  printf "%s" "$CONFIG_FILE"
}

mc_logs_dir() {
  printf "%s" "$LOG_DIR"
}

mc_runtime_dir() {
  printf "%s" "$RUNTIME_DIR"
}

mc_python() {
  /usr/bin/env python3 - "$CONFIG_FILE" "$@" <<'PY'
import json, sys, os, uuid, time

CONFIG = sys.argv[1]
args = sys.argv[2:]

def save(data):
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, CONFIG)

def iso_now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def compute_next_run(last_run, interval_days):
    try:
        interval_days = int(interval_days)
    except Exception:
        interval_days = 0
    interval_seconds = max(0, interval_days * 86400)
    base = time.time()
    if last_run:
        try:
            base = time.mktime(time.strptime(last_run, "%Y-%m-%dT%H:%M:%SZ"))
        except Exception:
            base = time.time()
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(base + interval_seconds))

def normalize(data):
    changed = False
    routines = data.get("routines", [])
    for r in routines:
        if "enabled" not in r:
            r["enabled"] = True
            changed = True
        if not r.get("next_run"):
            r["next_run"] = compute_next_run(r.get("last_run"), r.get("interval_days"))
            changed = True
    if changed:
        save(data)
    return data

def load():
    with open(CONFIG) as f:
        data = json.load(f)
    return normalize(data)

def add(path, interval_days):
    data = load()
    rid = "rt-" + uuid.uuid4().hex[:8]
    data["routines"].append({
        "id": rid,
        "path": os.path.abspath(path),
        "interval_days": int(interval_days),
        "last_run": None,
        "next_run": compute_next_run(None, interval_days),
        "enabled": True
    })
    save(data)
    print(rid)

def get(rid):
    data = load()
    for r in data["routines"]:
        if r["id"] == rid:
            print(json.dumps(r))
            return
    sys.exit(1)

def list_all():
    print(json.dumps(load()["routines"]))

def delete(rid):
    data = load()
    before = len(data["routines"])
    data["routines"] = [r for r in data["routines"] if r["id"] != rid]
    save(data)
    if len(data["routines"]) == before:
        sys.exit(1)

def update(rid, path, interval_days):
    data = load()
    found = False
    for r in data["routines"]:
        if r["id"] == rid:
            if path:
                r["path"] = os.path.abspath(path)
            if interval_days:
                r["interval_days"] = int(interval_days)
            r["next_run"] = compute_next_run(r.get("last_run"), r["interval_days"])
            found = True
            break
    if not found:
        sys.exit(1)
    save(data)

def touch_run(rid):
    data = load()
    found = False
    for r in data["routines"]:
        if r["id"] == rid:
            now = iso_now()
            r["last_run"] = now
            r["next_run"] = compute_next_run(now, r["interval_days"])
            found = True
            break
    if not found:
        sys.exit(1)
    save(data)

if not args:
    sys.exit(0)

cmd = args[0]
if cmd == "add":
    add(args[1], args[2])
elif cmd == "get":
    get(args[1])
elif cmd == "list":
    list_all()
elif cmd == "delete":
    delete(args[1])
elif cmd == "update":
    update(args[1], args[2], args[3])
elif cmd == "touch":
    touch_run(args[1])
else:
    sys.exit(1)
PY
}

mc_list_routines() {
  mc_ensure_config
  mc_python list
}

mc_get_routine() {
  local id="$1"
  mc_ensure_config
  mc_python get "$id"
}

mc_add_routine() {
  local path="$1"
  local interval_days="$2"
  mc_ensure_config
  mc_python add "$path" "$interval_days"
}

mc_update_routine() {
  local id="$1" path="$2" interval_days="$3"
  mc_ensure_config
  mc_python update "$id" "${path:-""}" "${interval_days:-""}"
}

mc_delete_routine() {
  local id="$1"
  mc_ensure_config
  mc_python delete "$id"
}

mc_mark_run() {
  local id="$1"
  mc_ensure_config
  mc_python touch "$id"
}

