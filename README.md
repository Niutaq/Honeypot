# IoT Honeypot Stack — Raspberry Pi (SIEM/NMS Demo)

Lekki system honeypot zoptymalizowany pod kątem **Raspberry Pi**, służący do wykrywania, analizowania i wizualizacji ataków na urządzenia IoT w czasie rzeczywistym.

---

## Co potrafi ten system?

- **Honeypoty IoT:** Symuluje usługi SSH/Telnet (**Cowrie**) oraz FTP, HTTP, MySQL, VNC (**OpenCanary**).
- **SIEM / Log Aggregation:** Centralny system zbierania logów oparty na **Grafana Loki** i **Promtail**.
- **NMS / Alerting:** Monitoring dostępności usług w czasie rzeczywistym przez **Uptime Kuma**.
- **Wizualizacja (Dashboard):** Dedykowany panel w Grafanie prezentujący:
    - **Liczba włamań (Success logins)** oraz prób Brute-force.
    - **Top 10 IP Atakujących** (ranking najbardziej aktywnych hostów).
    - **Analiza haseł** (najczęściej używane słowa ze słowników).
    - **Przechwycone komendy** (wszystko, co haker wpisał po zalogowaniu).
    - **Aktywność SSH vs IoT** (wykres aktywności poszczególnych usług).

---

## Szybki Start

### 1. Włączenie systemu
W głównym katalogu projektu wykonaj:
```bash
docker compose up -d
```

### 2. Dostęp do paneli WWW
| Narzędzie | URL | Dane logowania | Rola w projekcie |
| :--- | :--- | :--- | :--- |
| **Grafana** | `http://localhost:3000` | `http://pi-user.local:3000/dashboards` | `admin` / `admin` | SIEM — wizualizacja ataków |
| **Uptime Kuma** | `http://localhost:3001` | `http://pi-user.local:3001` | NMS — monitoring usług |

---

## 3. Struktura Projektu
- `docker-compose.yml` — definicja kontenerów (Cowrie, Canary, Loki, Grafana, Kuma).
- `logs/` — miejsce, gdzie Promtail "wyciąga" logi do wizualizacji.
- `grafana/dashboards/` — gotowa konfiguracja Twojego panelu SIEM.
- `cowrie/` & `opencanary/` — pliki konfiguracyjne symulowanych usług.

---

## Ważne Uwagi
- **Honeypot Cowrie** działa na porcie **2222**. Nie pomyl go ze swoim prawdziwym SSH na Raspberry Pi (port 22)!
- **Logi** są odświeżane w Grafanie co 5 sekund (można zmienić w prawym górnym rogu dashboardu).
