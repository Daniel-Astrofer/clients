#!/usr/bin/env bash
# Capture the Kerosene UI **as it already is** on your machine/device.
#
# Uses the session, balances, fonts and colors already on the device — does NOT
# create test accounts, does NOT run Tor signup, does NOT clear app state.
#
# ── Easiest paths ──────────────────────────────────────────────────
#
# A) Android (telefone com app já logado):
#      adb devices
#      bash tools/capture-device-screens.sh --android --guided --bring-front
#
# B) Linux (app com sua sessão local + botão de câmera no app):
#      bash tools/capture-device-screens.sh --linux-app
#      # abre o app com SCREEN_CAPTURE_UI; toque no FAB da câmera em cada tela
#
# C) Linux (foto da janela/OS, se o desktop permitir screenshot):
#      bash tools/capture-device-screens.sh --linux --guided
#
# Usage:
#   bash tools/capture-device-screens.sh              # auto: Android adb or Linux
#   bash tools/capture-device-screens.sh --android     # force adb device
#   bash tools/capture-device-screens.sh --linux       # desktop window/screen
#   bash tools/capture-device-screens.sh --linux-app   # flutter run + in-app camera FAB
#   bash tools/capture-device-screens.sh --now         # single shot of current screen
#   bash tools/capture-device-screens.sh --guided      # multi-shot: you navigate, Enter to shoot
#   bash tools/capture-device-screens.sh --bring-front # start/resume app (keeps data)
#   bash tools/capture-device-screens.sh --device=SERIAL
#
# Output (adb/OS): artifacts/visual_e2e/YYYYMMDD_HHMMSS_*.png
# Output (in-app): ~/Downloads/kerosene_captures/ or app documents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$FRONTEND"

OUT_ROOT="${VISUAL_E2E_OUT:-$FRONTEND/artifacts/visual_e2e}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$OUT_ROOT/$STAMP"
APP_ID="${KEROSENE_ANDROID_APPLICATION_ID:-com.kerosene.app}"
DEVICE_ID="${DEVICE_ID:-}"
MODE="auto"          # auto | android | linux | linux-app
SHOT_MODE="now"      # now | guided
BRING_FRONT=0
WINDOW_NAME_RE="${KEROSENE_WINDOW_RE:-[Kk]erosene}"

for arg in "$@"; do
  case "$arg" in
    --android) MODE="android" ;;
    --linux) MODE="linux" ;;
    --linux-app) MODE="linux-app" ;;
    --auto) MODE="auto" ;;
    --now) SHOT_MODE="now" ;;
    --guided) SHOT_MODE="guided" ;;
    --bring-front) BRING_FRONT=1 ;;
    --device=*) DEVICE_ID="${arg#--device=}" ;;
    --app-id=*) APP_ID="${arg#--app-id=}" ;;
    --out=*) OUT_ROOT="${arg#--out=}"; OUT_DIR="$OUT_ROOT/$STAMP" ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUT_DIR"

info() { echo "[capture] $*"; }
die() { echo "[capture][FAIL] $*" >&2; exit 1; }

# ── device detection ───────────────────────────────────────────────

first_adb_device() {
  command -v adb >/dev/null 2>&1 || return 1
  if [[ -n "$DEVICE_ID" ]]; then
    printf '%s\n' "$DEVICE_ID"
    return 0
  fi
  adb devices 2>/dev/null | awk '/\tdevice$/{print $1; exit}'
}

resolve_mode() {
  if [[ "$MODE" != "auto" ]]; then
    printf '%s\n' "$MODE"
    return
  fi
  if first_adb_device >/dev/null; then
    printf '%s\n' "android"
  else
    printf '%s\n' "linux"
  fi
}

# ── Android (real device / emulator, existing app data) ────────────

android_serial() {
  local s
  s="$(first_adb_device || true)"
  [[ -n "$s" ]] || die "Nenhum device Android em 'adb devices'. Conecte o telefone (USB debug) ou emulador."
  printf '%s\n' "$s"
}

android_bring_front() {
  local s="$1"
  info "Abrindo $APP_ID no device $s (sem limpar dados)"
  # Prefer launcher activity via monkey (no clear); fall back to main action.
  adb -s "$s" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 \
    >/dev/null 2>&1 || \
  adb -s "$s" shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$APP_ID" \
    >/dev/null 2>&1 || \
  adb -s "$s" shell am start -n "$APP_ID/.MainActivity" >/dev/null 2>&1 || true
  sleep 1.5
}

# True device framebuffer (what you see) — not widget golden, not test harness.
android_screencap() {
  local s="$1"
  local name="$2"
  local dest="$OUT_DIR/${name}.png"
  if ! adb -s "$s" exec-out screencap -p >"$dest" 2>/dev/null; then
    # Some devices need pull path
    adb -s "$s" shell screencap -p /sdcard/kero_cap.png
    adb -s "$s" pull /sdcard/kero_cap.png "$dest" >/dev/null
    adb -s "$s" shell rm -f /sdcard/kero_cap.png
  fi
  # Drop broken empty files
  if [[ ! -s "$dest" ]] || [[ "$(wc -c <"$dest")" -lt 1024 ]]; then
    rm -f "$dest"
    die "Falha ao capturar tela do Android ($name)"
  fi
  # Fix CRLF corruption some adb builds inject into PNG
  if ! file "$dest" 2>/dev/null | grep -qi 'PNG image'; then
    # try strip CR
    tr -d '\r' <"$dest" >"${dest}.fix" && mv "${dest}.fix" "$dest" || true
  fi
  info "OK Android → $dest ($(wc -c <"$dest") bytes)"
}

run_android() {
  local s
  s="$(android_serial)"
  info "Device Android: $s (dados do app já instalado — sessão real)"
  if [[ "$BRING_FRONT" == "1" ]]; then
    android_bring_front "$s"
  fi

  if [[ "$SHOT_MODE" == "now" ]]; then
    android_screencap "$s" "device_now"
    return
  fi

  # Guided: user navigates on the phone; we shoot on Enter.
  info "Modo guiado: navegue no telefone até a tela desejada e pressione Enter."
  info "Nomes sugeridos: home | settings | activity | receive | accounts | send"
  info "Digite 'q' + Enter para terminar."
  local n=1
  while true; do
    local label
    printf "Nome do shot [%02d] (ou Enter=shot_%02d, q=sair): " "$n" "$n"
    read -r label || break
    case "${label:-}" in
      q|Q|quit|exit) break ;;
      "") label=$(printf 'shot_%02d' "$n") ;;
    esac
    android_screencap "$s" "$label"
    n=$((n + 1))
  done
}

# ── Linux desktop (running Flutter window / full screen) ───────────

linux_capture_gnome() {
  local dest="$1"
  # GNOME Shell (Wayland). May require user session permission once.
  gdbus call --session \
    --dest org.gnome.Shell.Screenshot \
    --object-path /org/gnome/Shell/Screenshot \
    --method org.gnome.Shell.Screenshot.Screenshot \
    false false "$dest" >/dev/null 2>&1
  [[ -s "$dest" ]]
}

linux_capture_gnome_window() {
  local dest="$1"
  gdbus call --session \
    --dest org.gnome.Shell.Screenshot \
    --object-path /org/gnome/Shell/Screenshot \
    --method org.gnome.Shell.Screenshot.ScreenshotWindow \
    true false false "$dest" >/dev/null 2>&1
  [[ -s "$dest" ]]
}

linux_capture_grim() {
  local dest="$1"
  command -v grim >/dev/null 2>&1 || return 1
  grim "$dest"
  [[ -s "$dest" ]]
}

linux_capture_import() {
  local dest="$1"
  command -v import >/dev/null 2>&1 || return 1
  # Click window if no xdotool name match
  if command -v xdotool >/dev/null 2>&1; then
    local wid
    wid="$(xdotool search --name "$WINDOW_NAME_RE" 2>/dev/null | head -1 || true)"
    if [[ -n "$wid" ]]; then
      import -window "$wid" "$dest"
      [[ -s "$dest" ]] && return 0
    fi
  fi
  info "Clique na janela do Kerosene (ImageMagick import)…"
  import "$dest"
  [[ -s "$dest" ]]
}

linux_capture_scrot() {
  local dest="$1"
  command -v scrot >/dev/null 2>&1 || return 1
  scrot -u "$dest" 2>/dev/null || scrot "$dest"
  [[ -s "$dest" ]]
}

linux_capture_portal() {
  local dest="$1"
  # xdg-desktop-portal interactive screenshot (usually prompts the user).
  if command -v gnome-screenshot >/dev/null 2>&1; then
    gnome-screenshot -f "$dest" 2>/dev/null || gnome-screenshot -w -f "$dest" 2>/dev/null
    [[ -s "$dest" ]] && return 0
  fi
  if command -v spectacle >/dev/null 2>&1; then
    spectacle -b -n -o "$dest" 2>/dev/null
    [[ -s "$dest" ]] && return 0
  fi
  return 1
}

linux_screencap() {
  local name="$1"
  local dest="$OUT_DIR/${name}.png"
  local ok=0

  if linux_capture_gnome_window "$dest"; then ok=1
  elif linux_capture_gnome "$dest"; then ok=1
  elif linux_capture_grim "$dest"; then ok=1
  elif linux_capture_import "$dest"; then ok=1
  elif linux_capture_scrot "$dest"; then ok=1
  elif linux_capture_portal "$dest"; then ok=1
  fi

  if [[ "$ok" != "1" ]] || [[ ! -s "$dest" ]]; then
    rm -f "$dest"
    cat >&2 <<EOF
[capture][FAIL] Não consegui capturar a tela no Linux.

Opções:
  1) Abra o app:  flutter run -d linux
     (ou o binário em build/linux/…/kerosene) e rode de novo com --bring-front
  2) Instale uma ferramenta:  sudo apt install grim   # Wayland
     ou:  sudo apt install scrot imagemagick
  3) Se o GNOME bloquear screenshot (AccessDenied), autorize na notificação
     do sistema e rode de novo.
  4) Com telefone:  adb devices  &&  bash tools/capture-device-screens.sh --android
EOF
    exit 1
  fi
  info "OK Linux → $dest ($(wc -c <"$dest") bytes)"
}

linux_bring_front() {
  info "Subindo Kerosene no Linux (sessão local do OS — dados já salvos no secure storage)"
  # If already running, try focus; else start flutter run in background.
  if command -v xdotool >/dev/null 2>&1; then
    local wid
    wid="$(xdotool search --name "$WINDOW_NAME_RE" 2>/dev/null | head -1 || true)"
    if [[ -n "$wid" ]]; then
      xdotool windowactivate "$wid" 2>/dev/null || true
      return 0
    fi
  fi

  if pgrep -f 'build/linux/.*/kerosene' >/dev/null 2>&1 || pgrep -f 'flutter_tools.*linux' >/dev/null 2>&1; then
    info "Processo Linux já parece estar rodando"
    return 0
  fi

  info "Iniciando: flutter run -d linux (em background, log em $OUT_DIR/flutter_linux.log)"
  # shellcheck disable=SC1091
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
  nohup flutter run -d linux >"$OUT_DIR/flutter_linux.log" 2>&1 &
  echo $! >"$OUT_DIR/flutter_linux.pid"
  info "Aguardando janela (até ~90s)…"
  local i
  for i in $(seq 1 90); do
    if command -v xdotool >/dev/null 2>&1; then
      if xdotool search --name "$WINDOW_NAME_RE" 2>/dev/null | head -1 | grep -q .; then
        sleep 2
        return 0
      fi
    fi
    # Fallback: process alive long enough
    if [[ $i -gt 25 ]] && pgrep -f 'bundle/kerosene|flutter_linux' >/dev/null 2>&1; then
      sleep 3
      return 0
    fi
    sleep 1
  done
  info "Janela não detectada automaticamente — capture mesmo assim se o app estiver visível"
}

run_linux() {
  info "Modo Linux desktop (captura a janela/tela — dados da sessão local do app)"
  if [[ "$BRING_FRONT" == "1" ]]; then
    linux_bring_front
  fi

  if [[ "$SHOT_MODE" == "now" ]]; then
    linux_screencap "linux_now"
    return
  fi

  info "Modo guiado: navegue no app e pressione Enter para cada shot."
  info "Digite 'q' + Enter para terminar."
  local n=1
  while true; do
    local label
    printf "Nome do shot [%02d] (ou Enter=shot_%02d, q=sair): " "$n" "$n"
    read -r label || break
    case "${label:-}" in
      q|Q|quit|exit) break ;;
      "") label=$(printf 'shot_%02d' "$n") ;;
    esac
    linux_screencap "$label"
    n=$((n + 1))
  done
}

# Best Linux path: real app process + in-app red "FOTO" chip (no OS screenshot).
run_linux_app() {
  info "Linux in-app capture — usa a sessão/dados já no desktop"
  info "Procure o chip vermelho FOTO no canto SUPERIOR DIREITO"
  info "Atalho: Ctrl+Shift+S"
  info "PNGs em ~/Downloads/kerosene_captures/ (ou documents do app)"
  info "Ctrl+C neste terminal encerra o flutter run"
  # shellcheck disable=SC1091
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
  export PATH="${HOME}/.cargo/bin:${PATH:-}"
  # Explicit true so a stale build without auto-desktop logic still works.
  exec flutter run -d linux --dart-define=SCREEN_CAPTURE_UI=true
}

# ── main ───────────────────────────────────────────────────────────

main() {
  local mode
  mode="$(resolve_mode)"
  info "Saída: $OUT_DIR"
  info "Modo: $mode / shots: $SHOT_MODE"

  case "$mode" in
    android) run_android ;;
    linux) run_linux ;;
    linux-app) run_linux_app ;;
    *) die "modo desconhecido: $mode" ;;
  esac

  # linux-app exec's flutter run and never returns.
  info "Pronto. PNGs:"
  find "$OUT_DIR" -type f -name '*.png' -printf '  %p (%s bytes)\n' 2>/dev/null \
    || find "$OUT_DIR" -type f -name '*.png' -exec ls -la {} \;
  # Convenience symlink to latest run
  ln -sfn "$OUT_DIR" "$OUT_ROOT/latest"
  info "Atalho: $OUT_ROOT/latest/"
}

main
