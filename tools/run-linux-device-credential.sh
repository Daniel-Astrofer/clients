#!/usr/bin/env bash
# Run Kerosene Linux desktop — PRIMARY profile (isolated credentials).
#
# Isolation (must differ from run-linux-secondary.sh):
#   • KERO_SECURE_PREFIX=primary_   → secure storage / device keys
#   • KERO_PROFILE=primary          → device name / install id salt
#   • XDG under ~/.local/state/kerosene-profiles/primary
#
# Usage:
#   bash tools/run-linux-device-credential.sh
#   bash tools/run-linux-device-credential.sh --onion=http://your.onion
#   bash tools/run-linux-device-credential.sh --release --rebuild
#
# After the app starts (flutter console): r=reload R=restart q=quit
# Do NOT pass r/R/q as script arguments.
#
# DevTools (debug/profile) — fixed local ports:
#   http://127.0.0.1:9101  (DDS / DevTools UI)
#   http://127.0.0.1:9100/ (VM service)
# Override: KERO_DDS_PORT / KERO_VM_SERVICE_PORT

set -euo pipefail

# /tmp is a small partition; force Flutter build tool temp into /home
KFE_TMP="${KFE_TMP_DIR:-$HOME/.kfe-tmp}"
export TMPDIR="$KFE_TMP"
mkdir -p "$KFE_TMP"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT"
BIN="$FRONTEND/build/linux/x64/release/bundle/kerosene"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
ONION_URL="${ONION_URL:-}"
RUN_MODE="${KERO_LINUX_RUN_MODE:-debug}"
FORCE_REBUILD=0
DEVICE="${KERO_LINUX_DEVICE:-linux}"

# Force primary namespace — do NOT inherit ambient KERO_SECURE_PREFIX
PROFILE_LABEL="primary"
SECURE_PREFIX="primary_"
PRIMARY_HOME="${KERO_PRIMARY_HOME:-${HOME}/.local/state/kerosene-profiles/primary}"

# -- Isolated XDG for primary --
export KERO_PROFILE="$PROFILE_LABEL"
export KERO_SECURE_PREFIX="$SECURE_PREFIX"
export XDG_DATA_HOME="${PRIMARY_HOME}/share"
export XDG_CONFIG_HOME="${PRIMARY_HOME}/config"
export XDG_CACHE_HOME="${PRIMARY_HOME}/cache"
export XDG_STATE_HOME="${PRIMARY_HOME}/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
ln -sfn "${HOME}/.local/share/fonts"  "${XDG_DATA_HOME}/fonts"  2>/dev/null || true
ln -sfn "${HOME}/.local/share/icons"  "${XDG_DATA_HOME}/icons"  2>/dev/null || true
ln -sfn "${HOME}/.local/share/themes" "${XDG_DATA_HOME}/themes" 2>/dev/null || true
# --------------------------------------------------------------------

die() { echo "[FAIL] $*" >&2; exit 1; }

usage() {
  sed -n '2,20p' "$0"
}

is_flutter_interactive_key() {
  case "$1" in
    r|R|q|Q|v|V|h|H|d|D|s|S) return 0 ;;
    *) return 1 ;;
  esac
}

EXTRA_ARGS=()
while (($#)); do
  arg="$1"
  shift
  case "$arg" in
    --rebuild|-r) FORCE_REBUILD=1 ;;
    --onion=*) ONION_URL="${arg#--onion=}" ;;
    --onion)
      (($#)) || die "--onion requires a value"
      ONION_URL="$1"
      shift
      ;;
    --release) RUN_MODE=release ;;
    --profile) RUN_MODE=profile ;;
    --debug) RUN_MODE=debug ;;
    --device=*) DEVICE="${arg#--device=}" ;;
    --device)
      (($#)) || die "--device requires a value"
      DEVICE="$1"
      shift
      ;;
    --home=*)
      PRIMARY_HOME="${arg#--home=}"
      export XDG_DATA_HOME="${PRIMARY_HOME}/share"
      export XDG_CONFIG_HOME="${PRIMARY_HOME}/config"
      export XDG_CACHE_HOME="${PRIMARY_HOME}/cache"
      export XDG_STATE_HOME="${PRIMARY_HOME}/state"
      mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      if is_flutter_interactive_key "$arg"; then
        echo "[!] Ignoring '$arg' — interactive flutter key; type it after start." >&2
        continue
      fi
      EXTRA_ARGS+=("$arg")
      ;;
  esac
done

# Re-assert after flag parsing
export KERO_PROFILE="$PROFILE_LABEL"
export KERO_SECURE_PREFIX="$SECURE_PREFIX"

resolve_onion() {
  if [[ -n "${ONION_URL}" ]]; then
    printf '%s\n' "${ONION_URL}"
    return
  fi
  if [[ -n "${KERO_NODE_IS_URL:-}" ]]; then
    printf '%s\n' "${KERO_NODE_IS_URL}"
    return
  fi
  die "Set ONION_URL=http://….onion or KERO_NODE_IS_URL explicitly. Endpoint auto-discovery is intentionally disabled."
}

normalize_onion() {
  local u="$1"
  u="${u%%/}"
  if [[ "$u" != http://* && "$u" != https://* ]]; then
    u="http://${u}"
  fi
  local host
  host="$(python3 -c 'from urllib.parse import urlparse; import sys; print(urlparse(sys.argv[1]).hostname or "")' "$u")"
  [[ "$host" == *.onion ]] || die "ONION_URL must be a .onion HTTP URL, got: $u"
  printf '%s\n' "$u"
}

stamp_file() {
  printf '%s\n' "$FRONTEND/build/linux/x64/release/bundle/.kerosene-onion-stamp-primary"
}

needs_rebuild() {
  [[ "$FORCE_REBUILD" -eq 1 ]] && return 0
  [[ ! -x "$BIN" ]] && return 0
  local stamp stamped
  stamp="$(stamp_file)"
  [[ ! -f "$stamp" ]] && return 0
  stamped="$(tr -d '[:space:]' <"$stamp" || true)"
  [[ "$stamped" != "${ONION_URL}|${SECURE_PREFIX}" ]] && return 0
  return 1
}

ONION_URL="$(normalize_onion "$(resolve_onion)")"

command -v "$FLUTTER_BIN" >/dev/null 2>&1 || die "flutter not found (set FLUTTER_BIN=...)"
[[ -d "$FRONTEND" ]] || die "frontend dir missing: $FRONTEND"

DEFINE_ARGS=(
  --dart-define="KERO_NODE_IS_URL=${ONION_URL}"
  --dart-define="KERO_NODE_CH_URL=${ONION_URL}"
  --dart-define="KERO_NODE_SG_URL=${ONION_URL}"
  --dart-define=PREFER_CANONICAL_DEVICE_KEY_ENROLL=true
  --dart-define=ALLOW_WEBAUTHN_SHAPED_ENROLL=false
  --dart-define=ALLOW_WEBAUTHN_SHAPED_AUTH=false
  --dart-define=PREFER_DEVICE_KEY_ON_MOBILE=true
  --dart-define=DEVICE_KEY_LOGIN_ENABLED=true
)

echo "[*] profile:       $PROFILE_LABEL"
echo "[*] KERO_PROFILE:  $KERO_PROFILE"
echo "[*] secure prefix: $KERO_SECURE_PREFIX"
echo "[*] xdg root:      $PRIMARY_HOME"
echo "[*] onion:         $ONION_URL"
echo "[*] mode:          $RUN_MODE"
echo "[*] device:        $DEVICE"

cd "$FRONTEND"

if [[ "$RUN_MODE" == "release" ]]; then
  echo "[*] binary: $BIN"
  if needs_rebuild; then
    echo "[*] Building Linux release..."
    "$FLUTTER_BIN" build linux --release "${DEFINE_ARGS[@]}"
    mkdir -p "$(dirname "$(stamp_file)")"
    printf '%s\n' "${ONION_URL}|${SECURE_PREFIX}" >"$(stamp_file)"
  else
    echo "[*] Reusing release binary (stamp matches). Use --rebuild to force."
  fi
  [[ -x "$BIN" ]] || die "Binary missing after build: $BIN"
  echo "[*] Starting release binary with isolated primary credentials..."
  if ((${#EXTRA_ARGS[@]})); then
    exec env \
      KERO_PROFILE="$PROFILE_LABEL" \
      KERO_SECURE_PREFIX="$SECURE_PREFIX" \
      XDG_DATA_HOME="$XDG_DATA_HOME" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$BIN" "${EXTRA_ARGS[@]}"
  fi
  exec env \
    KERO_PROFILE="$PROFILE_LABEL" \
    KERO_SECURE_PREFIX="$SECURE_PREFIX" \
    XDG_DATA_HOME="$XDG_DATA_HOME" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_CACHE_HOME="$XDG_CACHE_HOME" \
    XDG_STATE_HOME="$XDG_STATE_HOME" \
    "$BIN"
fi

BUILD_KIND=debug
# Fixed DevTools / DDS ports (primary profile)
VM_SERVICE_PORT="${KERO_VM_SERVICE_PORT:-9100}"
DDS_PORT="${KERO_DDS_PORT:-9101}"
RUN_ARGS=(
  run
  -d "$DEVICE"
  --dds
  --host-vmservice-port="$VM_SERVICE_PORT"
  --dds-port="$DDS_PORT"
  --disable-service-auth-codes
  "${DEFINE_ARGS[@]}"
)
if [[ "$RUN_MODE" == "profile" ]]; then
  BUILD_KIND=profile
  RUN_ARGS+=(--profile)
else
  RUN_ARGS+=(--debug)
fi

BUNDLE_DIR="$FRONTEND/build/linux/x64/${BUILD_KIND}/bundle"
BUNDLE_LIB="$BUNDLE_DIR/lib"
BUILD_LOCK="${XDG_RUNTIME_DIR:-/tmp}/kerosene-flutter-linux.build.lock"

ensure_linux_bundle() {
  local need=0
  local so
  if [[ ! -x "$BUNDLE_DIR/kerosene" ]]; then
    need=1
  else
    for so in \
      libflutter_linux_gtk.so \
      libflutter_secure_storage_linux_plugin.so \
      liburl_launcher_linux_plugin.so
    do
      if [[ ! -s "$BUNDLE_LIB/$so" ]]; then
        need=1
        break
      fi
    done
  fi
  if [[ "$need" -eq 0 && "$FORCE_REBUILD" -eq 0 ]]; then
    echo "[*] Linux ${BUILD_KIND} bundle OK ($BUNDLE_DIR)"
    return 0
  fi
  echo "[*] Building Linux ${BUILD_KIND} under lock (plugins + binary)..."
  (
    flock 200
    if [[ "$BUILD_KIND" == "profile" ]]; then
      "$FLUTTER_BIN" build linux --profile "${DEFINE_ARGS[@]}"
    else
      "$FLUTTER_BIN" build linux --debug "${DEFINE_ARGS[@]}"
    fi
  ) 200>"$BUILD_LOCK"
  [[ -s "$BUNDLE_LIB/libflutter_secure_storage_linux_plugin.so" ]] || \
    die "Missing plugin after build: $BUNDLE_LIB/libflutter_secure_storage_linux_plugin.so"
  echo "[*] Build locked phase complete."
}

ensure_linux_bundle

export LD_LIBRARY_PATH="${BUNDLE_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

port_in_use() {
  local port="$1"
  ss -ltn "sport = :${port}" 2>/dev/null | grep -q LISTEN
}

if port_in_use "$DDS_PORT"; then
  echo "[!] DDS port ${DDS_PORT} already in use (primary Linux already running?)." >&2
  echo "[!] Do not relaunch this script — hot reload in the existing terminal (r/R)." >&2
  echo "[!] Second session options:" >&2
  echo "      bash tools/run-linux-secondary.sh          # Linux #2 → DDS 9111" >&2
  echo "      ONION_URL=$ONION_URL bash tools/run-android-local-full-onion.sh # Android → DDS 9102" >&2
  echo "[!] Or override: KERO_DDS_PORT=9103 $0 ..." >&2
  exit 1
fi

echo "[*] Starting flutter ${RUN_MODE}"
echo "[*] Expect log line: [kero] profile=primary secure_prefix=primary_ ..."
echo "[*] DevTools (fixed): http://127.0.0.1:${DDS_PORT}"
echo "[*] VM Service:       http://127.0.0.1:${VM_SERVICE_PORT}/"
echo "[*] After start: r=reload | R=restart | q=quit | d=open DevTools"
echo "[*] Tip: secondary can start after this finishes Building (shared build/linux)."
if ((${#EXTRA_ARGS[@]})); then
  echo "[*] cmd: $FLUTTER_BIN ${RUN_ARGS[*]} ${EXTRA_ARGS[*]}"
  exec env \
    KERO_PROFILE="$PROFILE_LABEL" \
    KERO_SECURE_PREFIX="$SECURE_PREFIX" \
    XDG_DATA_HOME="$XDG_DATA_HOME" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    XDG_CACHE_HOME="$XDG_CACHE_HOME" \
    XDG_STATE_HOME="$XDG_STATE_HOME" \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
    "$FLUTTER_BIN" "${RUN_ARGS[@]}" "${EXTRA_ARGS[@]}"
fi
echo "[*] cmd: $FLUTTER_BIN ${RUN_ARGS[*]}"
exec env \
  KERO_PROFILE="$PROFILE_LABEL" \
  KERO_SECURE_PREFIX="$SECURE_PREFIX" \
  XDG_DATA_HOME="$XDG_DATA_HOME" \
  XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
  XDG_CACHE_HOME="$XDG_CACHE_HOME" \
  XDG_STATE_HOME="$XDG_STATE_HOME" \
  LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
  "$FLUTTER_BIN" "${RUN_ARGS[@]}"
