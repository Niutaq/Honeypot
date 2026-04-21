# IoT Honeypot Stack — Raspberry Pi

Lekki i wydajny system honeypot zoptymalizowany pod kątem **Raspberry Pi 4 (ARM64)**. Projekt symuluje usługi IoT, zbiera logi bezpieczeństwa i wizualizuje ataki w czasie rzeczywistym.

## Architektura projektu

- **Honeypoty**: Cowrie (SSH/Telnet), OpenCanary (FTP, HTTP, MySQL, VNC).
- **SIEM / Logi**: Grafana Loki + Promtail (zbieranie, parsowanie i magazynowanie logów).
- **NMS / Alerty**: Uptime Kuma (monitoring dostępności usług w czasie rzeczywistym).
- **Wizualizacja**: Grafana (dedykowany dashboard "Honeypot IoT Security").

## Struktura plików

```text
honeypot/
├── docker-compose.yml       # Orkiestracja kontenerów
├── simulate_attack.sh       # Uniwersalny skrypt brute-force
├── logs/                    # Folder na logi (mapowany z hosta)
├── promtail/config.yml      # Logika parsowania logów JSON
├── grafana/                 # Konfiguracja i dashboardy SIEM
├── cowrie/                  # Konfiguracja honeypota SSH
└── opencanary/              # Konfiguracja usług IoT
```

## Kompletny repertuar komend

### 1. Zarządzanie systemem (Docker)
```bash
# Uruchomienie wszystkiego
docker compose up -d

# Sprawdzenie statusu kontenerów
docker compose ps

# Zatrzymanie systemu
docker compose down

# Pełny reset (usuwa zebrane dane i logi!)
docker compose down -v
```

### 2. Symulacja Ataków
```bash
# A. Automatyczny skrypt (uniwersalny macOS/Linux)
./simulate_attack.sh localhost 2222

# B. Atak słownikowy (Hydra)
hydra -l root -P rockyou_small.txt -s 2222 -t 4 localhost ssh

# C. Ręczna infiltracja (w celu pokazania logowania komend)
ssh -p 2222 root@localhost
```

### 3. Monitoring i Weryfikacja
```bash
# Sprawdzenie czy logi rosną na dysku
ls -lh logs/cowrie/cowrie.json

# Podgląd logów na żywo w terminalu
tail -f logs/cowrie/cowrie.json
```

## Dostęp do paneli (WWW)

| Narzędzie | URL | Creds | Cel |
| :--- | :--- | :--- | :--- |
| **Grafana** | `http://localhost:3000` | `admin` / `admin` | SIEM, wykresy, top haseł |
| **Uptime Kuma** | `http://localhost:3001` | (ustaw własne) | NMS, alarmy, status usług |

---

## Scenariusz Prezentacji (Demo)

1. **NMS (Uptime Kuma)**:
   - Wejdź na `http://pi-user.local:3001`.
   - Dodaj Monitor: `TCP Port`, Host: `172.22.0.10`, Port: `2222`, Nazwa: `Honeypot SSH`.
   - Pokaż zielony status usługi.

2. **SIEM (Grafana)**:
   - Wejdź na `http://pi-user.local:3000` -> Dashboards -> **Honeypot IoT Security Dashboard**.
   - Ustaw odświeżanie na `5s` i zakres `Last 15 minutes`.

3. **Atak Real-Time**:
   - Uruchom **Hydra** w terminalu.
   - Wróć do Grafany i obserwuj jak wykresy rosną, a tabela "Live Attack Logs" zapełnia się danymi.

4. **Analiza Działań**:
   - Zaloguj się przez SSH ręcznie, wpisz kilka komend (np. `whoami`, `uname -a`).
   - Pokaż te komendy w panelu Grafany jako "przechwycone działania atakującego".

---

## Rozwiązywanie problemów
- **Brak danych w Grafanie**: Upewnij się, że plik `logs/cowrie/cowrie.json` nie jest pusty i ma uprawnienia do odczytu (`chmod -R 777 logs`).
- **Hydra error**: Upewnij się, że składnia jest poprawna: `hydra [opcje] [host] [protokół]`.
