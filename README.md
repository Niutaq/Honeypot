# IoT Honeypot Stack — Raspberry Pi (SIEM/NMS Demo)

Profesjonalny i lekki system honeypot zoptymalizowany pod kątem **Raspberry Pi**, służący do wykrywania, analizowania i wizualizacji ataków na urządzenia IoT w czasie rzeczywistym.

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
| **Grafana** | `http://localhost:3000` | `admin` / `admin` | SIEM — wizualizacja ataków |
| **Uptime Kuma** | `http://localhost:3001` | (ustaw przy 1. wejściu) | NMS — monitoring usług |

---

## Prezentacja

### KROK 1: Symulacja ataku Brute-force
Otwórz dashboard w Grafanie i uruchom skrypt symulujący tysiące prób logowania z bazy `rockyou`:
```bash
./simulate_attack.sh localhost 2222
```
*Efekt:* Zobaczysz, jak w Grafanie licznik **"Nieudane Próby"** rośnie, a wykresy IP i haseł zaczynają się zapełniać.

### KROK 2: Interaktywne włamanie
Zaloguj się do honeypota jako napastnik, aby wygenerować "krytyczne" zdarzenie:
```bash
ssh root@localhost -p 2222
# Hasło: dowolne (np. 123456)
```
Po zalogowaniu wpisz kilka komend "szpiegowskich":
```bash
whoami
cat /etc/passwd
ls -la /tmp
exit
```
*Efekt:* W Grafanie zaświeci się panel **"Udane Logowania"**, a w sekcji **"Wykonywane Komendy"** pojawią się Twoje wpisy.

### KROK 3: Monitoring NMS
Wejdź do **Uptime Kuma** i pokaż zielony status usług. Możesz wyłączyć na chwilę honeypota (`docker compose stop cowrie`), aby pokazać jak system NMS wykrywa awarię i alarmuje o braku dostępności usługi IoT.

---

## Struktura Projektu
- `docker-compose.yml` — definicja kontenerów (Cowrie, Canary, Loki, Grafana, Kuma).
- `logs/` — miejsce, gdzie Promtail "wyciąga" logi do wizualizacji.
- `grafana/dashboards/` — gotowa konfiguracja Twojego panelu SIEM.
- `cowrie/` & `opencanary/` — pliki konfiguracyjne symulowanych usług.

---

## Ważne Uwagi
- **Honeypot Cowrie** działa na porcie **2222**. Nie pomyl go ze swoim prawdziwym SSH na Raspberry Pi (port 22)!
- **Logi** są odświeżane w Grafanie co 5 sekund (można zmienić w prawym górnym rogu dashboardu).
