#!/usr/bin/env bash
# Launch Kerosene Flutter (Android) against the local-full Tor onion backend.
#
# Usage (from anywhere):
#   bash frontend/tools/run-android-local-full-onion.sh
#   bash frontend/tools/run-android-local-full-onion.sh --device=192.168.3.99:33913
#   ONION_URL=http://your.onion bash frontend/tools/run-android-local-full-onion.sh
#   bash frontend/tools/run-android-local-full-onion.sh --release
#
# Always uses the user-writable SDK at ~/Android/Sdk (Platform 36 + NDK live there).
# Do NOT rely on /opt/android-sdk alone — Platform 36 cannot be installed there without root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND="$ROOT/frontend"
NS="${KEROSENE_NAMESPACE:-kerosene-local}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
RELEASE=0
DEVICE_ID="${DEVICE_ID:-}"
ONION_URL="${ONION_URL:-}"

# Prefer user SDK (writable). Fall back only if missing.
USER_SDK="${HOME}/Android/Sdk"
if [[ -d "${USER_SDK}/platforms/android-36" ]]; then
  export ANDROID_HOME="${ANDROID_HOME_OVERRIDE:-$USER_SDK}"
else
  export ANDROID_HOME="${ANDROID_HOME_OVERRIDE:-${ANDROID_HOME:-$USER_SDK}}"
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$USER_SDK/ndk/28.2.13676358}"

# Rust/cargo for Tor cargokit
# shellcheck disable=SC1091
[[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
export PATH="${HOME}/.cargo/bin:${PATH}"

# adb from user or system SDK
if [[ -x "${ANDROID_HOME}/platform-tools/adb" ]]; then
  export PATH="${ANDROID_HOME}/platform-tools:${PATH}"
elif [[ -x /opt/android-sdk/platform-tools/adb ]]; then
  export PATH="/opt/android-sdk/platform-tools:${PATH}"
fi

for arg in "$@"; do
  case "$arg" in
    --release) RELEASE=1 ;;
    --device=*) DEVICE_ID="${arg#--device=}" ;;
    --onion=*) ONION_URL="${arg#--onion=}" ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

die() { echo "[FAIL] $*" >&2; exit 1; }

resolve_onion() {
  if [[ -n "${ONION_URL}" ]]; then
    printf '%s\n' "${ONION_URL}"
    return
  fi
  if [[ -n "${KERO_NODE_IS_URL:-}" ]]; then
    printf '%s\n' "${KERO_NODE_IS_URL}"
    return
  fi
  if [[ -f "$ROOT/infra/status.sh" ]]; then
    local line host
    line="$(bash "$ROOT/infra/status.sh" 2>/dev/null | grep -E 'tor onion:' | head -1 || true)"
    host="$(printf '%s\n' "$line" | grep -oE 'http://[a-z2-7]+\.onion' | head -1 || true)"
    if [[ -n "$host" ]]; then
      printf '%s\n' "$host"
      return
    fi
  fi
  die "Could not resolve onion URL. Pass --onion=http://….onion, ONION_URL, or KERO_NODE_IS_URL (no hardcoded onion in-repo)."
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

# Force local.properties every run so Flutter does not silently fall back to /opt.
ensure_local_properties() {
  local props="$FRONTEND/android/local.properties"
  local flutter_sdk="${FLUTTER_ROOT:-/opt/flutter}"
  [[ -d "$flutter_sdk" ]] || flutter_sdk="$(dirname "$(dirname "$(command -v "$FLUTTER_BIN")")")"

  cat >"$props" <<EOF
sdk.dir=${ANDROID_HOME}
flutter.sdk=${flutter_sdk}
flutter.versionName=1.0.0
flutter.versionCode=1
flutter.buildMode=debug
android.useAndroidX=true
android.enableJetifier=true
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.parallel=false
ndk.dir=${ANDROID_NDK_HOME}
EOF
  echo "[*] wrote $props (sdk.dir=${ANDROID_HOME})"
}

pick_android_device() {
  local id=""
  # 1) adb devices
  if command -v adb >/dev/null 2>&1; then
    id="$(adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}' || true)"
  fi
  # 2) flutter devices (ASCII-safe parse: id is second column around bullet or spaces)
  if [[ -z "$id" ]] && command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
    id="$(
      "$FLUTTER_BIN" devices 2>/dev/null \
        | grep -i android \
        | grep -v 'emulator' \
        | head -1 \
        | sed -E 's/.*[•∙·][[:space:]]*([^[:space:]•∙·]+)[[:space:]]*[•∙·].*/\1/' \
        || true
    )"
    # Fallback: look for host:port pattern
    if [[ -z "$id" || "$id" == *"android"* ]]; then
      id="$(
        "$FLUTTER_BIN" devices 2>/dev/null \
          | grep -oE '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+|[A-Za-z0-9]{6,})' \
          | head -1 \
          || true
      )"
    fi
  fi
  printf '%s\n' "$id"
}

# ---- main ----
ONION_URL="$(normalize_onion "$(resolve_onion)")"

command -v "$FLUTTER_BIN" >/dev/null 2>&1 || die "flutter not found on PATH (set FLUTTER_BIN=...)"
[[ -d "$FRONTEND" ]] || die "frontend dir missing: $FRONTEND"
[[ -f "$FRONTEND/pubspec.yaml" ]] || die "pubspec.yaml missing under $FRONTEND"
[[ -d "${ANDROID_HOME}/platforms/android-36" ]] || die \
  "Android SDK Platform 36 missing at ${ANDROID_HOME}/platforms/android-36 — reinstall with sdkmanager into ~/Android/Sdk"
[[ -f "${ANDROID_NDK_HOME}/source.properties" ]] || die \
  "NDK missing/incomplete at ${ANDROID_NDK_HOME}"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(pick_android_device || true)"
fi
if [[ -z "$DEVICE_ID" ]]; then
  echo "[FAIL] No Android device found." >&2
  echo "  adb devices" >&2
  echo "  flutter devices" >&2
  echo "  or: DEVICE_ID=192.168.3.99:33913 bash $0" >&2
  exit 1
fi

ensure_local_properties

echo "[*] frontend: $FRONTEND"
echo "[*] ANDROID_HOME=${ANDROID_HOME}"
echo "[*] ANDROID_NDK_HOME=${ANDROID_NDK_HOME}"
echo "[*] onion:    $ONION_URL"
echo "[*] device:   $DEVICE_ID"
echo "[*] rustc:    $(command -v rustc 2>/dev/null || echo MISSING)"

cd "$FRONTEND"

MODE_ARGS=(--debug)
[[ "$RELEASE" -eq 1 ]] && MODE_ARGS=(--release)

DEFINE_ARGS=(
  --dart-define="KERO_NODE_IS_URL=${ONION_URL}"
  --dart-define="KERO_NODE_CH_URL=${ONION_URL}"
  --dart-define="KERO_NODE_SG_URL=${ONION_URL}"
)

# shellcheck disable=SC2206
EXTRA=( ${EXTRA_FLUTTER_ARGS:-} )

# Default DDS away from primary Linux (9101) when both runs are active.
VM_SERVICE_PORT="${KERO_VM_SERVICE_PORT:-9999}"
DDS_PORT="${KERO_DDS_PORT:-9102}"

echo "[*] running: flutter run -d $DEVICE_ID -t lib/mobile_main.dart ..."
echo "[*] DevTools/DDS: vm=${VM_SERVICE_PORT} dds=${DDS_PORT}"
exec "$FLUTTER_BIN" run \
  -d "$DEVICE_ID" \
  -t lib/mobile_main.dart \
  --host-vmservice-port="$VM_SERVICE_PORT" \
  --dds-port="$DDS_PORT" \
  --disable-service-auth-codes \
  "${MODE_ARGS[@]}" \
  "${DEFINE_ARGS[@]}" \
  "${EXTRA[@]}"
