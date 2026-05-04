# IoT Honeypot Stack — Raspberry Pi (SIEM/NMS Demo)

Lekki system honeypot zoptymalizowany pod kątem **Raspberry Pi**, służący do wykrywania, analizowania i wizualizacji ataków na urządzenia IoT w czasie rzeczywistym.

---

## Co potrafi ten system?

* **Honeypoty IoT:** Symulacja usług SSH/Telnet (**Cowrie**) oraz FTP, HTTP, MySQL, VNC (**OpenCanary**).
* **SIEM / Log Aggregation:** Centralny system zbierania logów oparty na **Grafana Loki** i **Promtail**.
* **NMS / Alerting:** Monitoring dostępności usług w czasie rzeczywistym przez **Uptime Kuma**.
* **Wizualizacja (Dashboard):** Dedykowany panel w Grafanie prezentujący:

  * **Liczba włamań (Success logins)** oraz prób Brute-force.
  * **Top 10 IP Atakujących** (ranking najbardziej aktywnych hostów).
  * **Analiza haseł** (najczęściej używane słowa ze słowników).
  * **Przechwycone komendy** (historia poleceń wpisanych po zalogowaniu).
  * **Aktywność SSH vs IoT** (wykres aktywności poszczególnych usług).

---

## Szybki Start

#### Włączenie systemu

W głównym katalogu projektu należy wykonać:

```bash
docker compose up -d
```

#### Dostęp do paneli WWW

| Narzędzie       | URL                                                                | Dane logowania                   | Rola w projekcie           |
| :-------------- | :----------------------------------------------------------------- | :------------------------------- | :------------------------- |
| **Grafana**     | `http://localhost:3000` lub `http://pi-user.local:3000/dashboards` | `admin` / `admin`                | SIEM — wizualizacja ataków |
| **Uptime Kuma** | `http://localhost:3001` lub `http://pi-user.local:3001`            | (ustawiane przy 1. uruchomieniu) | NMS — monitoring usług     |

---

## Konfiguracja Monitoringu (Uptime Kuma)

W panelu Uptime Kuma (NMS) dodaj nowe monitory typu **TCP Port**, używając nazw kontenerów (Docker DNS):

* **Honeypot SSH:** Hostname: `cowrie`, Port: `2222`
* **Honeypot MySQL:** Hostname: `opencanary`, Port: `3306`
* **Loki (SIEM):** Hostname: `loki`, Port: `3100`

---

## Dostęp Zdalny (SSH poza domem)

Aby bezpiecznie łączyć się z Raspberry Pi z dowolnego miejsca bez przekierowywania portów, zainstaluj **Tailscale**:

1. Na Raspberry Pi: `curl -fsSL https://tailscale.com/install.sh | sh`
2. Zaloguj się: `sudo tailscale up`
3. Zainstaluj Tailscale na swoim laptopie i używaj adresu IP z panelu Tailscale w swoim aliasie `ssh pi`.

---

## Demo: Atakowanie z zewnątrz (scenariusz akademicki)

Ten scenariusz zakłada kontrolowany test za zgodą operatora honeypota. Publiczny adres WWW wystawia tylko fałszywy portal nginx na porcie 80; formularz `/login` jest proxy do OpenCanary HTTP, więc próby logowania trafiają do Loki/Grafany.

### 1. Operator uruchamia stack na Raspberry Pi

```bash
docker compose up -d
```

### 2. Operator wystawia portal przez Tailscale Serve/Funnel

W panelu Tailscale włącz możliwość publicznego wystawiania usługi, a na Raspberry Pi uruchom:

```bash
tailscale serve --bg http://localhost:80
tailscale serve status | grep "https://" >> Tailscale_adres.txt
```

Skrypt idempotentny wykonujący ten sam krok:

```bash
./deploy/setup.sh
```

Fallback ngrok, jeśli Tailscale Serve/Funnel nie jest dostępny:

```bash
cp .env.example .env
# wpisz NGROK_AUTHTOKEN w pliku .env
docker compose --profile ngrok up -d ngrok
docker compose logs ngrok
```

### 3. Operator przekazuje adres publiczny

Przykład:

```bash
PUBLIC_URL="https://pi-user.tail1234.ts.net"
PUBLIC_HOST="pi-user.tail1234.ts.net"
PUBLIC_IP="<PUBLIC_IP_OR_TAILSCALE_IP>"
```

### 4. Atakujący uruchamia testy

```bash
nmap -sV "$PUBLIC_HOST"

hydra -l admin -P rockyou_small.txt \
  ssh://"$PUBLIC_IP" -s 2222 -t 4

hydra -l admin -P rockyou_small.txt \
  "$PUBLIC_HOST" https-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 443

curl "$PUBLIC_URL/.env"
curl "$PUBLIC_URL/wp-login.php"
```

Dla tunelu bez TLS użyj `http-post-form -s 80` zamiast `https-post-form -s 443`.

### 5. Operator monitoruje zdarzenia w Grafanie

LAN:

```bash
http://pi-user.local:3000
```

Tunel SSH przez Tailscale:

```bash
ssh -L 3000:localhost:3000 pi@<TAILSCALE_IP>
```

Następnie otwórz na laptopie:

```bash
http://localhost:3000
```

Panele WWW w dashboardzie:

* `Top Attacked Web Paths`
* `Web Login Attempts`
* `Attacker User-Agents`
* `Attack Timeline (All Services)`

---

## Symulacja Ataku i Pentesting (Scenariusze)

Poniższe komendy pozwalają na przetestowanie systemu i wygenerowanie danych dla stosu SIEM (Grafana/Loki).

### 1. Rekonesans (Nmap)

```bash
nmap -sV -p 21,80,161,2222,3306,5900,8080 localhost
```

Efekt: Wyświetlenie listy otwartych portów (SSH, FTP, HTTP, MySQL, VNC). Skanowanie zostaje odnotowane w logach Promtail/Loki.

### 2. Atak Brute-Force SSH (Hydra)

```bash
hydra -l root -P rockyou_small.txt ssh://localhost:2222 -t 4
```

Efekt: Wzrost liczby nieudanych prób logowania w Grafanie oraz wypełnienie dashboardu najczęściej używanymi hasłami ze słownika.

### 3. Skrypt symulacyjny

```bash
chmod +x simulate_attack.sh
./simulate_attack.sh localhost 2222
# albo cel zewnętrzny:
./simulate_attack.sh https://pi-user.tail1234.ts.net 2222
```

Efekt: Sekwencyjne testowanie kombinacji login:hasło dla SSH oraz formularza `/login`, plus skanowanie bait URL-i [WWW](http://WWW).

### 4. Interaktywna sesja SSH

```bash
ssh root@localhost -p 2222
# Hasło: dowolne (np. 123456)
```

Przykładowe polecenia:

```bash
whoami
cat /etc/passwd
ls -la /tmp
uname -a
exit
```

Efekt: Aktualizacja panelu Udane Logowania w Grafanie oraz zapisanie historii poleceń.

### 5. Testy innych usług (OpenCanary)

* FTP: ftp localhost 21
* MySQL: mysql -h localhost -P 3306 -u root -p

---

### Struktura Projektu

* `docker-compose.yml`
* `decoy-web/`
* `logs/`
* `grafana/dashboards/`
* `cowrie/`, `opencanary/`

---

## Ważne Uwagi

* **Cowrie działa na porcie 2222**
* **Odświeżanie logów: 5 sekund**

---
---
---
---
---
---
---
-_--_--_--_--_--_--_--_--_--_-
---
---
---
---
---
---
---
---
---

# IoT Honeypot Stack — Raspberry Pi (SIEM/NMS Demo)

A lightweight honeypot system optimized for **Raspberry Pi**, designed to detect, analyze, and visualize attacks on IoT devices in real time.

---

## What can this system do?

* **IoT Honeypots:** Simulation of SSH/Telnet (**Cowrie**) and FTP, HTTP, MySQL, VNC (**OpenCanary**).
* **SIEM / Log Aggregation:** Centralized logging using **Grafana Loki** and **Promtail**.
* **NMS / Alerting:** Real-time monitoring via **Uptime Kuma**.
* **Visualization (Dashboard):**

  * Successful logins and brute-force attempts
  * Top 10 attacking IPs
  * Password analysis
  * Captured commands
  * SSH vs IoT activity

---

## Quick Start

```bash
docker compose up -d
```

---

## Monitoring Setup

* `cowrie:2222`
* `opencanary:3306`
* `loki:3100`

---

## Remote Access

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

---

## Attack Demo

```bash
nmap -sV "$PUBLIC_HOST"
```

---

## Notes

* Cowrie runs on port 2222
* Log refresh: 5 seconds
