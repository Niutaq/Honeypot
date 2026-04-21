#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Honeypot Stack — macOS & Linux Setup Script
# ═══════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      IoT Honeypot Stack - macOS/Linux    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Sprawdzenie systemu ────────────────────────────────
IS_MAC=false
if [ "$(uname)" == "Darwin" ]; then
    IS_MAC=true
    log "Wykryto system macOS."
fi

# ── Konfiguracja Swap (tylko Linux) ────────────────────
setup_swap() {
    if $IS_MAC; then return; fi
    if [ -f /swapfile ] || grep -q "/swapfile" /proc/swaps; then
        log "Plik swap już istnieje. Pomijam."
    else
        log "Tworzę plik swap (2GB)..."
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
}

# ── Sprawdzenie Dockera ────────────────────────────────
check_docker() {
    if ! command -v docker &>/dev/null; then
        if $IS_MAC; then
            err "Docker nie jest zainstalowany! Zainstaluj OrbStack lub Docker Desktop."
            exit 1
        else
            warn "Instaluję Docker (Linux)..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
        fi
    else
        log "Docker OK: $(docker --version)"
    fi
}

# ── Konfiguracja Portów (tylko Linux) ──────────────────
setup_firewall() {
    if $IS_MAC; then
        warn "macOS nie wspiera iptables. SSH będzie dostępne TYLKO na porcie 2222."
        return
    fi
    log "Konfiguracja iptables (22->2222)..."
    sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222 2>/dev/null || true
}

# ── WYKONANIE ──────────────────────────────────────────
setup_swap
check_docker
setup_firewall

log "Tworzę strukturę katalogów..."
mkdir -p cowrie opencanary logstash/pipeline filebeat

log "Uruchamiam honeypot stack..."
docker compose pull
docker compose up -d

# ── Status ─────────────────────────────────────────────
IP_ADDR="localhost"
SSH_PORT="2222"
[ "$IS_MAC" = false ] && SSH_PORT="22 (->2222)"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║              STACK URUCHOMIONY                ║"
echo "╠═══════════════════════════════════════════════╣"
echo "║  Zabbix Web       → http://localhost:8085     ║"
echo "║  Honeypot SSH     → port $SSH_PORT            ║"
echo "║  OpenCanary HTTP  → port 80                   ║"
echo "║  OpenCanary FTP   → port 21                   ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
log "Atakuj wpisując: ./simulate_attack.sh localhost 2222"
