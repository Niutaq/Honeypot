#!/bin/bash
# Idempotent deployment helper for the Raspberry Pi demo stack.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAILSCALE_FILE="$PROJECT_DIR/Tailscale_adres.txt"

cd "$PROJECT_DIR"

log "Tworzę wymagane katalogi, jeśli ich brakuje."
mkdir -p cowrie opencanary promtail grafana/dashboards decoy-web logs/cowrie logs/opencanary
touch "$TAILSCALE_FILE"

if ! command -v docker >/dev/null 2>&1; then
    err "Docker nie jest zainstalowany albo nie jest w PATH."
    exit 1
fi

log "Uruchamiam lub odświeżam stack Docker Compose."
docker compose pull
docker compose up -d

if command -v tailscale >/dev/null 2>&1; then
    log "Wystawiam decoy-web przez Tailscale Serve na porcie 80."
    tailscale serve --bg http://localhost:80

    log "Zapisuję publiczny adres Tailscale Serve do Tailscale_adres.txt."
    tmp_file="$(mktemp)"
    if tailscale serve status | grep "https://" > "$tmp_file"; then
        while IFS= read -r line; do
            if ! grep -Fxq "$line" "$TAILSCALE_FILE"; then
                printf '%s\n' "$line" >> "$TAILSCALE_FILE"
            fi
        done < "$tmp_file"
    else
        warn "Nie znaleziono adresu https:// w wyniku 'tailscale serve status'."
    fi
    rm -f "$tmp_file"
else
    warn "Tailscale nie jest dostępny na hoście. Użyj fallbacku ngrok z profilem Compose."
fi

log "Gotowe."
echo "Grafana LAN: http://pi-user.local:3000"
echo "Decoy Web LAN: http://localhost"
echo "Ngrok fallback: docker compose --profile ngrok up -d ngrok"
