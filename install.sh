#!/usr/bin/env bash
set -euo pipefail
umask 022

# WattRadar Installer/Updater (DietPi / arm64)
# Usage:
#   sudo bash install_wattradar.sh                 # neueste STABLE
#   sudo bash install_wattradar.sh --pre           # neueste PRE-RELEASE
#   sudo bash install_wattradar.sh --tag v1.0.0    # bestimmte Version
#   sudo bash install_wattradar.sh --repo owner/repo
# Optional: export GITHUB_TOKEN=... (für höhere API-Limits/private Repos)

APP_NAME="wattRadar"
REPO="${REPO:-ehive-dev/wattRadar-releases}"  # per --repo überschreibbar
CHANNEL="stable"    # stable | pre
TAG="${TAG:-}"      # vX.Y.Z (mit v)
ARCH_REQ="arm64"

# ---------- CLI-Args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pre) CHANNEL="pre"; shift ;;
    --stable) CHANNEL="stable"; shift ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: sudo $0 [--pre|--stable] [--tag vX.Y.Z] [--repo owner/repo]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ---------- Helpers ----------
info(){ printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok(){   printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err(){  printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; }

need_root(){
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "Bitte als root ausführen (sudo)."
    exit 1
  fi
}
need_tools(){
  command -v curl >/dev/null || { apt-get update -y; apt-get install -y curl; }
  command -v jq   >/dev/null || { apt-get update -y; apt-get install -y jq; }
  command -v ss   >/dev/null 2>&1 || true
}

api(){
  local url="$1"
  local hdr=(-H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    hdr+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  curl -fsSL "${hdr[@]}" "$url"
}

trim_one_line(){ tr -d '\r' | tr -d '\n' | sed 's/[[:space:]]\+$//'; }

get_release_json(){
  if [[ -n "$TAG" ]]; then
    api "https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
  else
    api "https://api.github.com/repos/${REPO}/releases?per_page=25" \
    | jq -c "
        if \"${CHANNEL}\" == \"pre\" then
          ([ .[] | select(.draft==false and .prerelease==true) ] | .[0])
        else
          ([ .[] | select(.draft==false and .prerelease==false) ] | .[0])
        end
      "
  fi
}

pick_deb_from_release(){
  # Erwartet das JSON EINER Release auf stdin, gibt EXAKT EINE URL aus (oder leer)
  jq -r --arg arch "$ARCH_REQ" --arg app "$APP_NAME" '
    .assets // []
    | map(select(.name | test("^" + $app + "_.*_" + $arch + "\\.deb$")))
    | .[0].browser_download_url // empty
  '
}

installed_version(){ dpkg-query -W -f='${Version}\n' "$APP_NAME" 2>/dev/null || true; }

get_port(){
  local p="3005"  # Default für WattRadar
  if [[ -r "/etc/default/${APP_NAME}" ]]; then
    # shellcheck disable=SC1091
    . "/etc/default/${APP_NAME}" || true
    p="${PORT:-3005}"
  fi
  echo "$p"
}
get_health_path(){
  local hp="/healthz"
  if [[ -r "/etc/default/${APP_NAME}" ]]; then
    # shellcheck disable=SC1091
    . "/etc/default/${APP_NAME}" || true
    hp="${HEALTH_PATH:-/healthz}"
  fi
  echo "$hp"
}

wait_port(){
  local port="$1"
  command -v ss >/dev/null 2>&1 || return 0
  for i in {1..60}; do ss -ltn 2>/dev/null | grep -q ":${port} " && return 0; sleep 0.5; done
  return 1
}
wait_health(){
  local url="$1"
  for i in {1..30}; do curl -fsS "$url" >/dev/null && return 0; sleep 1; done
  return 1
}

# ---------- Start ----------
need_root
need_tools

ARCH_SYS="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
if [[ "$ARCH_SYS" != "$ARCH_REQ" ]]; then
  warn "Systemarchitektur ist '$ARCH_SYS', Release ist für '$ARCH_REQ'. Abbruch."
  exit 1
fi

OLD_VER="$(installed_version || true)"
if [[ -n "$OLD_VER" ]]; then
  info "Installiert: ${APP_NAME} ${OLD_VER}"
else
  info "Keine bestehende ${APP_NAME}-Installation gefunden."
fi

info "Ermittle Release aus ${REPO} (${CHANNEL}${TAG:+, tag=$TAG}) ..."
RELEASE_JSON="$(get_release_json)"
if [[ -z "$RELEASE_JSON" || "$RELEASE_JSON" == "null" ]]; then
  err "Keine passende Release gefunden."
  exit 1
fi

TAG_NAME="$(printf '%s' "$RELEASE_JSON" | jq -r '.tag_name')"
[[ -z "$TAG" ]] && TAG="$TAG_NAME"
VER_CLEAN="${TAG#v}"

DEB_URL_RAW="$(printf '%s' "$RELEASE_JSON" | pick_deb_from_release || true)"
DEB_URL="$(printf '%s' "$DEB_URL_RAW" | trim_one_line)"

if [[ -z "$DEB_URL" ]]; then
  err "Kein .deb Asset (${ARCH_REQ}) in Release ${TAG} gefunden."
  exit 1
fi

TMPDIR="$(mktemp -d -t wattradar-install.XXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
DEB_FILE="${TMPDIR}/${APP_NAME}_${VER_CLEAN}_${ARCH_REQ}.deb"

info "Lade: ${DEB_URL}"
curl -fL --retry 3 --retry-delay 1 -o "$DEB_FILE" "$DEB_URL"

dpkg-deb --info "$DEB_FILE" >/dev/null 2>&1 || { err "Ungültiges .deb"; exit 1; }

if systemctl list-units --type=service | grep -q "^${APP_NAME}\.service"; then
  systemctl stop "$APP_NAME" || true
fi

info "Installiere Paket ..."
set +e
dpkg -i "$DEB_FILE"
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
  warn "dpkg -i scheiterte — versuche apt --fix-broken"
  apt-get update -y
  apt-get -f install -y
  dpkg -i "$DEB_FILE"
fi
ok "Installiert: ${APP_NAME} ${VER_CLEAN}"

systemctl daemon-reload || true
systemctl enable "$APP_NAME" || true
systemctl restart "$APP_NAME" || true

PORT="$(get_port)"
H_PATH="$(get_health_path)"
URL="http://127.0.0.1:${PORT}${H_PATH}"

info "Warte auf Port :${PORT} ..."
wait_port "$PORT" || { err "Port ${PORT} lauscht nicht."; journalctl -u "$APP_NAME" -n 200 --no-pager -o cat || true; exit 1; }

info "Prüfe Health ${URL} ..."
wait_health "$URL" || { err "Health-Check fehlgeschlagen."; journalctl -u "$APP_NAME" -n 200 --no-pager -o cat || true; exit 1; }

NEW_VER="$(installed_version || echo "$VER_CLEAN")"
ok "Fertig: ${APP_NAME} ${OLD_VER:+${OLD_VER} → }${NEW_VER} (healthy @ ${URL})"
