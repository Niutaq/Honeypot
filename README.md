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
| Narzędzie | URL | Dane logowania
| :--- | :--- | :--- |
| **Grafana** | `http://localhost:3000` (lokalnie) lub `http://pi-user.local:3000/dashboards` (RPi) | `admin` / `admin` | SIEM — wizualizacja ataków |
| **Uptime Kuma** | `http://localhost:3001` (lokalnie) lub `http://pi-user.local:3001` (RPi) | ...

## Symulacja Ataku i Pentesting (Scenariusze)

Poniższe komendy pozwalają na przetestowanie systemu i wygenerowanie danych dla stosu SIEM (Grafana/Loki).

### 1. Rekonesans (Nmap)
Skanowanie usług wystawianych przez symulowany system IoT:
```bash
nmap -sV -p 21,80,161,2222,3306,5900,8080 localhost
```
Efekt: Wyświetlenie listy otwartych portów (SSH, FTP, HTTP, MySQL, VNC). Skanowanie zostaje odnotowane w logach Promtail/Loki.

### 2. Atak Brute-Force SSH (Hydra)
Wykorzystanie narzędzia Hydra do łamania haseł przy użyciu dołączonego słownika rockyou_small.txt:
```bash
hydra -l root -P rockyou_small.txt ssh://localhost:2222 -t 4
```
Efekt: Wzrost liczby nieudanych prób logowania w Grafanie oraz wypełnienie dashboardu najczęściej używanymi hasłami ze słownika.

### 3. Skrypt symulacyjny
Uruchomienie dołączonego skryptu Bash, który symuluje automatyczny atak brute-force:
```bash
chmod +x simulate_attack.sh
./simulate_attack.sh localhost 2222
```
Efekt: Sekwencyjne testowanie kombinacji login:hasło i raportowanie statusu prób.

### 4. Interaktywna sesja SSH
Manualne zalogowanie do honeypota w celu wygenerowania zdarzenia typu "Krytyczne":
```bash
ssh root@localhost -p 2222
# Hasło: dowolne (np. 123456)
```
Przykładowe polecenia do wykonania po uzyskaniu dostępu:
```bash
whoami
cat /etc/passwd
ls -la /tmp
uname -a
exit
```
Efekt: Aktualizacja panelu Udane Logowania w Grafanie oraz zapisanie pełnej historii wpisanych poleceń w sekcji Wykonywane Komendy.

### 5. Testy innych usług (OpenCanary)
Symulacja prób dostępu do usług FTP lub MySQL:
- FTP: ftp localhost 21
- MySQL: mysql -h localhost -P 3306 -u root -p

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
