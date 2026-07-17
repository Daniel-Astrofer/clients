#!/usr/bin/env bash
# =============================================================================
# Gera PNGs das telas (qualidade golden) com dados do SEU device.
# NÃO usa Tor, NÃO pede senha, NÃO captura Overlay preto.
#
# Fluxo:
#   1) App logado → toque DADOS  (grava device_ui_snapshot.json)
#   2) bash tools/device-snapshot-goldens.sh
#      → flutter test pinta as telas com o JSON e grava PNGs
#
# Uso:
#   bash tools/device-snapshot-goldens.sh
#   bash tools/device-snapshot-goldens.sh --linux
#   bash tools/device-snapshot-goldens.sh --android
#   bash tools/device-snapshot-goldens.sh --from=/path/device_ui_snapshot.json
#   bash tools/device-snapshot-goldens.sh --skip-pull   # usa fixture já copiada
#
# Saída:
#   test/goldens/real_data/goldens/real_*.png
#   artifacts/visual_e2e/latest/*.png
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$FRONTEND"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
FIXTURE_DIR="$FRONTEND/test/goldens/real_data/fixtures"
FIXTURE="$FIXTURE_DIR/device_ui_snapshot.json"
OUT_GOLDENS="$FRONTEND/test/goldens/real_data/goldens"
OUT_VIEW="$FRONTEND/artifacts/visual_e2e"
MODE="auto"
SKIP_PULL=0
FROM_PATH=""
APP_ID="${KEROSENE_ANDROID_APPLICATION_ID:-com.kerosene.app}"

for arg in "$@"; do
  case "$arg" in
    --android) MODE="android" ;;
    --linux) MODE="linux" ;;
    --skip-pull) SKIP_PULL=1 ;;
    --from=*) FROM_PATH="${arg#--from=}" ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck disable=SC1091
[[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
export PATH="${HOME}/.cargo/bin:${PATH:-}"

info() { echo "[device-goldens] $*"; }
die() { echo "[device-goldens][FAIL] $*" >&2; exit 1; }

mkdir -p "$FIXTURE_DIR" "$OUT_VIEW"

first_adb() {
  command -v adb >/dev/null 2>&1 || return 1
  adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}'
}

pull_android() {
  local serial remote="" c
  serial="$(first_adb || true)"
  [[ -n "$serial" ]] || die "Sem device adb. Conecte o telefone ou use --linux / --from="

  info "Android $serial — procurando device_ui_snapshot.json"
  local candidates=(
    "/sdcard/Download/kerosene_captures/device_ui_snapshot.json"
    "/storage/emulated/0/Download/kerosene_captures/device_ui_snapshot.json"
    "/sdcard/Download/device_ui_snapshot.json"
  )
  for c in "${candidates[@]}"; do
    if adb -s "$serial" shell "test -s '$c'" 2>/dev/null; then
      remote="$c"
      break
    fi
  done

  if [[ -z "$remote" ]]; then
    local run_as_path
    run_as_path="$(
      adb -s "$serial" shell \
        "run-as $APP_ID sh -c 'ls app_flutter/kerosene_captures/device_ui_snapshot.json 2>/dev/null; ls files/kerosene_captures/device_ui_snapshot.json 2>/dev/null'" \
        2>/dev/null | tr -d '\r' | head -1 || true
    )"
    if [[ -n "$run_as_path" ]]; then
      adb -s "$serial" exec-out run-as "$APP_ID" cat "$run_as_path" >"$FIXTURE"
      [[ -s "$FIXTURE" ]] || die "run-as pull vazio"
      info "Pull run-as → $FIXTURE ($(wc -c <"$FIXTURE") bytes)"
      return
    fi
    die "JSON não encontrado no phone. App logado → toque DADOS → rode de novo."
  fi

  adb -s "$serial" pull "$remote" "$FIXTURE" >/dev/null
  [[ -s "$FIXTURE" ]] || die "adb pull falhou"
  info "Pull $remote → $FIXTURE ($(wc -c <"$FIXTURE") bytes)"
}

pull_linux() {
  local src="" c
  local candidates=(
    "${HOME}/Downloads/kerosene_captures/device_ui_snapshot.json"
    "${XDG_DOWNLOAD_DIR:-$HOME/Downloads}/kerosene_captures/device_ui_snapshot.json"
  )
  while IFS= read -r f; do
    [[ -n "$f" ]] && candidates+=("$f")
  done < <(find "${HOME}/.local/share" -name 'device_ui_snapshot.json' 2>/dev/null | head -30 || true)

  for c in "${candidates[@]}"; do
    if [[ -f "$c" && -s "$c" ]]; then src="$c"; break; fi
  done
  [[ -n "$src" ]] || die "JSON não encontrado no Linux. App → DADOS → ~/Downloads/kerosene_captures/"
  cp -f "$src" "$FIXTURE"
  info "Copiado $src → $FIXTURE ($(wc -c <"$FIXTURE") bytes)"
}

install_fixture() {
  if [[ -n "$FROM_PATH" ]]; then
    [[ -s "$FROM_PATH" ]] || die "Arquivo inexistente: $FROM_PATH"
    cp -f "$FROM_PATH" "$FIXTURE"
    info "FROM $FROM_PATH"
    return
  fi
  if [[ "$SKIP_PULL" == "1" ]]; then
    [[ -s "$FIXTURE" ]] || die "Sem fixture em $FIXTURE"
    info "Usando $FIXTURE"
    return
  fi
  # Prefer existing fixture if fresh enough? Always re-pull when possible.
  local mode="$MODE"
  if [[ "$mode" == "auto" ]]; then
    if first_adb >/dev/null 2>&1; then mode="android"; else mode="linux"; fi
  fi
  case "$mode" in
    android) pull_android ;;
    linux) pull_linux ;;
    *) die "modo $mode" ;;
  esac
}

validate_fixture() {
  python3 - <<'PY'
import json, os, sys
p = os.environ["FIXTURE"]
d = json.load(open(p))
assert "user" in d, "missing user"
w = d.get("wallets") or []
t = d.get("transactions") or []
u = (d.get("user") or {}).get("username") or "?"
print(f"[device-goldens] snapshot user={u!r} wallets={len(w)} txs={len(t)}")
if len(w) == 0 and len(t) == 0:
    print("[device-goldens][WARN] wallets e txs vazios — Home ainda não tinha dados ao exportar DADOS", file=sys.stderr)
PY
}

render_goldens() {
  export FIXTURE="$FIXTURE"
  export DEVICE_SNAPSHOT_PATH="$FIXTURE"
  validate_fixture

  info "Render golden (flutter test pinta widgets de verdade)…"
  "$FLUTTER_BIN" test \
    test/goldens/real_data/real_screens_golden_test.dart \
    --dart-define=RUN_REAL_GOLDENS=true \
    --update-goldens

  # golden_toolkit costuma gravar em test/goldens/real_data/goldens/
  mkdir -p "$OUT_GOLDENS"
  local stamp out_run
  stamp="$(date +%Y%m%d_%H%M%S)"
  out_run="$OUT_VIEW/screens_$stamp"
  mkdir -p "$out_run"

  local count=0
  while IFS= read -r -d '' png; do
    cp -f "$png" "$out_run/"
    cp -f "$png" "$OUT_GOLDENS/" 2>/dev/null || true
    count=$((count + 1))
    local sz
    sz=$(wc -c <"$png" | tr -d ' ')
    info "  $(basename "$png") ($sz bytes)"
    if [[ "$sz" -lt 15000 ]]; then
      info "  WARN: PNG muito pequeno — possível tela vazia"
    fi
  done < <(find test/goldens/real_data -name 'real_*.png' -print0 2>/dev/null)

  if [[ "$count" -eq 0 ]]; then
    # fallback any png under real_data
    while IFS= read -r -d '' png; do
      cp -f "$png" "$out_run/"
      count=$((count + 1))
      info "  $(basename "$png") ($(wc -c <"$png") bytes)"
    done < <(find test/goldens/real_data -name '*.png' -print0 2>/dev/null)
  fi

  [[ "$count" -gt 0 ]] || die "Nenhum PNG gerado pelo flutter test"

  cp -f "$FIXTURE" "$out_run/device_ui_snapshot.json"
  ln -sfn "$out_run" "$OUT_VIEW/latest"

  info "Cópias fáceis de abrir:"
  info "  $out_run/"
  info "  $OUT_VIEW/latest/"
  ls -la "$OUT_VIEW/latest/" || true
}

main() {
  info "cwd=$FRONTEND"
  install_fixture
  render_goldens
  info "FEITO — abra os PNGs em artifacts/visual_e2e/latest/"
}

main
