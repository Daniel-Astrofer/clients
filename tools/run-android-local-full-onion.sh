#!/usr/bin/env bash
# Launch Kerosene on connected Android devices using the native Docker Tor
# ingress, with Kind discovery as a fallback. Explicit onion values override both.
#
# Usage (from anywhere):
#   bash tools/run-android-local-full-onion.sh
#   bash tools/run-android-local-full-onion.sh --dry-run
#   bash tools/run-android-local-full-onion.sh --onion=http://your.onion
#   bash tools/run-android-local-full-onion.sh --device=192.168.3.99:33913
#   bash tools/run-android-local-full-onion.sh --capture-ui
#   bash tools/run-android-local-full-onion.sh --release --onion=http://your.onion
#
# Always uses the user-writable SDK at ~/Android/Sdk (Platform 36 + NDK live there).
# Do NOT rely on /opt/android-sdk alone — Platform 36 cannot be installed there without root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
RELEASE=0
DRY_RUN=0
CAPTURE_UI=0
DEVICE_ID="${DEVICE_ID:-}"
ONION_URL="${ONION_URL:-}"
TEMP_DISCOVERY_KUBECONFIG=""

cleanup_discovery_kubeconfig() {
  if [[ -n "$TEMP_DISCOVERY_KUBECONFIG" ]]; then
    rm -f "$TEMP_DISCOVERY_KUBECONFIG"
  fi
}
trap cleanup_discovery_kubeconfig EXIT

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
    --capture-ui) CAPTURE_UI=1 ;;
    --dry-run) DRY_RUN=1 ;;
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

  # The running native stack publishes the web/API Hidden Service from this
  # Tor container. It is independent of the Kubernetes Tor StatefulSet.
  if command -v docker >/dev/null 2>&1 && \
    [[ "$(docker inspect --format '{{.State.Running}}' kerosene-native-web-tor 2>/dev/null || true)" == "true" ]]; then
    local hostname
    hostname="$(docker exec kerosene-native-web-tor cat /service/hostname 2>/dev/null | tr -d '\r\n' || true)"
    [[ "$hostname" =~ ^[a-z2-7]{56}\.onion$ ]] \
      || die "Native Tor is running but /service/hostname is missing or invalid."
    echo "[*] using native Docker Tor ingress kerosene-native-web-tor" >&2
    printf 'http://%s\n' "$hostname"
    return
  fi

  command -v kubectl >/dev/null 2>&1 || die "kubectl is required to discover the running onion (or pass --onion)."
  local config="${KEROSENE_KUBECONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/kerosene/kubeconfig}"
  local namespace="${KEROSENE_NAMESPACE:-}" pods pod_namespace pod ready hostname context cluster
  local -a context_kube=(kubectl)
  if [[ -f "$config" ]]; then
    context_kube+=(--kubeconfig "$config")
  fi

  # The Kerosene kubeconfig can retain an old localhost port after Kind has
  # recreated its API server. Export the current Kind endpoint to a temporary
  # file rather than overwriting the user's dedicated kubeconfig.
  context="$("${context_kube[@]}" config current-context 2>/dev/null || true)"
  if [[ "$context" == kind-* ]] && command -v kind >/dev/null 2>&1; then
    cluster="${context#kind-}"
    TEMP_DISCOVERY_KUBECONFIG="$(mktemp "${TMPDIR:-/tmp}/kerosene-kind-kubeconfig.XXXXXX")"
    if kind export kubeconfig --name "$cluster" \
      --kubeconfig "$TEMP_DISCOVERY_KUBECONFIG" >/dev/null 2>&1; then
      config="$TEMP_DISCOVERY_KUBECONFIG"
      echo "[*] refreshed temporary kubeconfig from Kind cluster $cluster" >&2
    else
      die "Cannot refresh Kind context $context. Start the kerosene-local control plane, or pass --onion=http://<hostname>.onion."
    fi
  fi

  local -a kube=(kubectl --request-timeout=10s)
  if [[ -f "$config" ]]; then
    kube+=(--kubeconfig "$config")
  fi
  local -a scope=()
  if [[ -n "$namespace" ]]; then
    scope=(-n "$namespace")
  else
    scope=(-A)
  fi
  pods="$("${kube[@]}" "${scope[@]}" get pods \
    -l app.kubernetes.io/name=tor-onion \
    -o 'jsonpath={range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}')" \
    || die "Cannot inspect Tor ingress pods in the cluster."
  local -a candidates=()
  local -a not_ready=()
  while IFS=$'\t' read -r pod_namespace pod ready; do
    [[ -n "$pod" ]] || continue
    if [[ "$ready" != True ]]; then
      not_ready+=("$pod_namespace/$pod")
      continue
    fi
    hostname="$("${kube[@]}" -n "$pod_namespace" exec "$pod" -c tor -- \
      cat /var/lib/tor/kerosene_service/hostname)" \
      || die "Cannot read onion hostname from $pod_namespace/$pod."
    hostname="${hostname//$'\r'/}"
    [[ "$hostname" =~ ^[a-z2-7]{56}\.onion$ ]] || die "Invalid onion hostname from $pod."
    candidates+=("http://$hostname")
  done <<< "$pods"
  if ((${#candidates[@]} == 0)); then
    if ((${#not_ready[@]} > 0)); then
      die "Tor ingress found but not Ready: ${not_ready[*]}. Inspect the staging-tor rollout and its required secrets."
    fi
    if [[ -n "$namespace" ]]; then
      die "No Tor ingress pod found in namespace $namespace. Deploy the Tor workload or unset KEROSENE_NAMESPACE to search all namespaces."
    fi
    die "No Tor ingress pod exists in any namespace. The app cannot reach its API until the staging-tor workload and required secrets are deployed."
  fi
  local selected="${candidates[0]}" candidate
  for candidate in "${candidates[@]}"; do
    [[ "$candidate" == "$selected" ]] || die "Multiple Tor onions found; select one with --onion."
  done
  printf '%s\n' "$selected"
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

connected_android_devices() {
  command -v adb >/dev/null 2>&1 || die "adb not found on PATH."
  local devices
  devices="$(adb devices)" || die "Cannot list Android devices."
  awk 'NR > 1 && $2 == "device" {print $1}' <<< "$devices"
}

# ---- main ----
ONION_URL="$(resolve_onion)"
ONION_URL="$(normalize_onion "$ONION_URL")"

DEVICE_LIST="$(connected_android_devices)"
DEVICES=()
while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if [[ -z "$DEVICE_ID" || "$id" == "$DEVICE_ID" ]]; then
    DEVICES+=("$id")
  fi
done <<< "$DEVICE_LIST"
((${#DEVICES[@]})) || die "No authorized Android devices connected${DEVICE_ID:+ matching $DEVICE_ID}. Check adb devices."

echo "[*] onion: $ONION_URL"
printf '[*] device: %s\n' "${DEVICES[@]}"
if ((DRY_RUN)); then
  echo "[*] dry-run: no build, installation, or configuration writes."
  exit 0
fi

command -v "$FLUTTER_BIN" >/dev/null 2>&1 || die "flutter not found on PATH (set FLUTTER_BIN=...)"
[[ -f "$FRONTEND/pubspec.yaml" ]] || die "pubspec.yaml missing under $FRONTEND"
[[ -d "${ANDROID_HOME}/platforms/android-36" ]] || die "Android SDK Platform 36 missing at $ANDROID_HOME"
[[ -f "${ANDROID_NDK_HOME}/source.properties" ]] || die "NDK missing/incomplete at $ANDROID_NDK_HOME"

ensure_local_properties

echo "[*] frontend: $FRONTEND"
echo "[*] ANDROID_HOME=${ANDROID_HOME}"
echo "[*] ANDROID_NDK_HOME=${ANDROID_NDK_HOME}"
echo "[*] onion:    $ONION_URL"
echo "[*] rustc:    $(command -v rustc 2>/dev/null || echo MISSING)"

cd "$FRONTEND"

MODE_ARGS=(--debug)
[[ "$RELEASE" -eq 1 ]] && MODE_ARGS=(--release)

DEFINE_ARGS=(
  --dart-define="KERO_NODE_IS_URL=${ONION_URL}"
  --dart-define="KERO_NODE_CH_URL=${ONION_URL}"
  --dart-define="KERO_NODE_SG_URL=${ONION_URL}"
)
((CAPTURE_UI == 0)) || DEFINE_ARGS+=(--dart-define=SCREEN_CAPTURE_UI=true)

# shellcheck disable=SC2206
EXTRA=( ${EXTRA_FLUTTER_ARGS:-} )

# Default DDS away from primary Linux (9101) when both runs are active.
VM_SERVICE_PORT="${KERO_VM_SERVICE_PORT:-9999}"
DDS_PORT="${KERO_DDS_PORT:-9102}"

# Launch sequentially to avoid concurrent Gradle builds in the same checkout.
# With multiple devices, detach after each launch so every phone is started.
RUN_ARGS=()
((${#DEVICES[@]} <= 1)) || RUN_ARGS+=(--no-resident)
failed=0
for index in "${!DEVICES[@]}"; do
  device="${DEVICES[$index]}"
  echo "[*] running on $device"
  if ! "$FLUTTER_BIN" run \
    -d "$device" \
    -t lib/mobile_main.dart \
    --host-vmservice-port="$((VM_SERVICE_PORT + index))" \
    --dds-port="$((DDS_PORT + index))" \
    "${MODE_ARGS[@]}" \
    "${DEFINE_ARGS[@]}" \
    "${RUN_ARGS[@]}" \
    "${EXTRA[@]}"; then
    echo "[FAIL] Launch failed on $device" >&2
    failed=1
  fi
done
exit "$failed"
