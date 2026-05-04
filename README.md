# IoT Honeypot Stack - Raspberry Pi

Projekt demonstracyjny honeypota uruchamianego na Raspberry Pi. Stack zbiera i wizualizuje ataki na usługi SSH/Telnet, FTP, HTTP, MySQL, VNC oraz na fałszywą stronę WWW wystawioną publicznie przez Tailscale Serve/Funnel.

Ten projekt jest przeznaczony do kontrolowanego scenariusza akademickiego. Nie używaj prawdziwych danych logowania. Atakujący powinien używać wyłącznie testowych haseł ze słownika `rockyou_small.txt`.

## Architektura

Usługi:

| Usługa | Rola | Port |
| :--- | :--- | :--- |
| `cowrie` | SSH/Telnet honeypot | `2222`, `2223` |
| `opencanary` | FTP/HTTP/MySQL/VNC honeypot | `21`, `8082`, `3306`, `5900` |
| `decoy-web` | Fałszywa strona WWW na NGINX | `80` |
| `loki` | Agregacja logów | `3100` |
| `promtail` | Zbieranie logów do Loki | brak portu |
| `grafana` | Dashboard SIEM | `3000` |
| `uptime-kuma` | Monitoring usług | `3001` |
| `ngrok` | Fallback tunelu publicznego | profil `ngrok` |

Najważniejszy przepływ WWW:

```text
Atakujący -> publiczny URL Tailscale -> RPi:80 -> decoy-web/NGINX
                                              -> /login proxy do OpenCanary:8080
                                              -> log NGINX JSON do logs/nginx/access.log
                                              -> log OpenCanary do logs/opencanary/opencanary.log
                                              -> Promtail -> Loki -> Grafana
```

## Szybki Start

Na Raspberry Pi:

```bash
cd ~/honeypot
docker compose up -d
docker compose ps
```

Panel Grafana:

```text
http://localhost:3000
login: admin
hasło: admin
```

Panel Uptime Kuma:

```text
http://localhost:3001
```

## Demo: atakowanie z zewnątrz

### Role w prezentacji

| Rola | Co robi |
| :--- | :--- |
| Raspberry Pi | Uruchamia kontenery, wystawia fałszywą stronę przez Tailscale |
| Administrator na laptopie | Łączy się z RPi, ogląda Grafanę i logi |
| Atakujący | Dostaje publiczny URL i wykonuje testy `curl`, przeglądarką, Hydrą |

## 1. Raspberry Pi - przygotowanie

Wejdź do katalogu projektu:

```bash
cd ~/honeypot
```

Uruchom stack:

```bash
docker compose up -d
docker compose ps
```

Sprawdź, czy działa fałszywa strona:

```bash
curl -I http://localhost
curl http://localhost/.env
```

Sprawdź log NGINX:

```bash
tail -n 5 logs/nginx/access.log
```

Sprawdź log OpenCanary:

```bash
tail -n 5 logs/opencanary/opencanary.log
```

## 2. Raspberry Pi - wystawienie WWW przez Tailscale

Włącz Serve/Funnel w panelu administracyjnym Tailscale, a potem na RPi:

```bash
tailscale serve --bg http://localhost:80
tailscale serve status
```

Zapisz publiczny URL:

```bash
tailscale serve status | grep "https://" >> Tailscale_adres.txt
cat Tailscale_adres.txt
```

Przykład URL:

```text
https://pi-user.tail8a7b69.ts.net
```

Możesz też uruchomić skrypt idempotentny:

```bash
./deploy/setup.sh
```

## 3. Administrator - laptop połączony z RPi

Połącz się z RPi:

```bash
ssh pi@<TAILSCALE_IP_RPI>
```

Opcjonalny tunel do Grafany:

```bash
ssh -L 3000:localhost:3000 pi@<TAILSCALE_IP_RPI>
```

Na laptopie otwórz:

```text
http://localhost:3000
```

W Grafanie wybierz dashboard:

```text
Honeypot IoT Security Dashboard
```

Ustaw:

```text
Time range: Last 5 minutes
Refresh: 5s
```

Panele ważne podczas demo:

| Panel | Co pokazuje |
| :--- | :--- |
| `Logi Ataków w Czasie Rzeczywistym (Live)` | Surowe zdarzenia Cowrie, OpenCanary i NGINX |
| `Top Attacked Web Paths` | Najczęściej odwiedzane ścieżki, np. `/.env`, `/wp-login.php` |
| `Web Login Attempts` | Login/hasło z POST na `/login` |
| `Attacker User-Agents` | Hydra, curl, przeglądarka, skanery |
| `Attack Timeline (All Services)` | Oś czasu SSH + HTTP + FTP + MySQL |

## 4. Atakujący - przeglądarka

Atakujący dostaje URL:

```text
https://pi-user.tail8a7b69.ts.net
```

W przeglądarce:

1. Otwiera publiczny URL.
2. Widzi fałszywą stronę `Materiały dla studentów`.
3. Wpisuje testowe hasła, np.:

```text
admin
password
student
test123
```

Formularz wysyła POST na:

```text
/login
```

To powinno pojawić się w Grafanie w panelach `Web Login Attempts` i `Logi Ataków w Czasie Rzeczywistym (Live)`.

## 5. Atakujący - curl

Ustaw zmienną:

```bash
PUBLIC_URL="https://pi-user.tail8a7b69.ts.net"
```

Skanowanie przynęt WWW:

```bash
curl -k "$PUBLIC_URL/"
curl -k "$PUBLIC_URL/dydaktyka-g/materialy-dla-studentow"
curl -k "$PUBLIC_URL/.env"
curl -k "$PUBLIC_URL/wp-login.php"
curl -k "$PUBLIC_URL/phpmyadmin"
curl -k "$PUBLIC_URL/config.php"
curl -k "$PUBLIC_URL/backup.zip"
curl -k "$PUBLIC_URL/api/v1/users"
```

Ręczna próba logowania:

```bash
curl -k -X POST "$PUBLIC_URL/login" \
  -d "username=admin&password=test123" \
  -A "Mozilla/5.0 (compatible; scanner)"
```

## 6. Atakujący - Hydra HTTP POST

Polecana komenda dla publicznego URL Tailscale HTTPS:

```bash
hydra -I -l admin -P rockyou_small.txt \
  pi-user.tail8a7b69.ts.net https-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 443
```

Znaczenie:

| Element | Znaczenie |
| :--- | :--- |
| `-I` | ignoruje stary plik `hydra.restore` i startuje od początku |
| `-l admin` | stały login testowy |
| `-P rockyou_small.txt` | lista haseł |
| `https-post-form` | moduł Hydry dla formularza HTTPS |
| `/login:username=^USER^&password=^PASS^:Invalid` | endpoint, dane POST i warunek błędu |
| `-s 443` | port HTTPS Tailscale Serve/Funnel |

Dla HTTP bez TLS:

```bash
hydra -I -l admin -P rockyou_small.txt \
  <HOST_LUB_IP> http-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 80
```

## 7. Atakujący - SSH Cowrie

Tailscale Serve wystawia głównie WWW. SSH Cowrie na porcie `2222` musi być osiągalny osobno, np. przez LAN, Tailscale IP, przekierowanie portu albo tunel TCP.

Lokalnie/LAN:

```bash
hydra -I -l admin -P rockyou_small.txt ssh://<IP_RPI> -s 2222 -t 4
```

Test ręczny:

```bash
ssh root@<IP_RPI> -p 2222
```

W Grafanie zdarzenia Cowrie będą widoczne jako `cowrie.session.connect`, `cowrie.login.failed`, `cowrie.login.success` itd.

## 8. Skrypt symulacyjny

Lokalnie:

```bash
./simulate_attack.sh localhost 2222
```

Na publiczny URL:

```bash
./simulate_attack.sh https://pi-user.tail8a7b69.ts.net 2222
```

Skrypt robi:

| Część | Działanie |
| :--- | :--- |
| SSH | próbuje kilku loginów i haseł na Cowrie |
| HTTP POST | wysyła hasła z `rockyou_small.txt` na `/login` |
| HTTP paths | odpytuje `/.env`, `/wp-login.php`, `/phpmyadmin`, `/config.php` itd. |

## 9. Prezentacja

Kolejność prezentacji:

1. Na RPi pokaż działające kontenery:

```bash
docker compose ps
```

2. Pokaż publiczny URL:

```bash
tailscale serve status
```

3. Na laptopie otwórz Grafanę:

```text
http://localhost:3000
```

4. Atakujący otwiera publiczny URL w przeglądarce i wpisuje testowe hasła.

5. Atakujący uruchamia:

```bash
curl -k https://pi-user.tail8a7b69.ts.net/.env
curl -k https://pi-user.tail8a7b69.ts.net/wp-login.php
hydra -I -l admin -P rockyou_small.txt \
  pi-user.tail8a7b69.ts.net https-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 443
```

6. Administrator pokazuje w Grafanie:

| Dowód | Panel |
| :--- | :--- |
| Atakowane ścieżki | `Top Attacked Web Paths` |
| Hasła z formularza | `Web Login Attempts` |
| Narzędzia atakującego | `Attacker User-Agents` |
| Czas ataku | `Attack Timeline (All Services)` |
| Surowe logi | `Logi Ataków w Czasie Rzeczywistym (Live)` |

## 10. Gdy Grafana pokazuje `No data`

Najpierw wygeneruj świeży ruch:

```bash
PUBLIC_URL="https://pi-user.tail8a7b69.ts.net"

curl -k "$PUBLIC_URL/.env"
curl -k -X POST "$PUBLIC_URL/login" \
  -d "username=admin&password=test123" \
  -A "curl-test"
```

Sprawdź log NGINX na RPi:

```bash
tail -n 20 logs/nginx/access.log
```

Jeśli nie ma wpisów, problem jest przed NGINX: Tailscale Serve, URL, port 80 albo kontener `decoy-web`.

Sprawdź kontenery:

```bash
docker compose ps
docker compose logs --tail=50 decoy-web
docker compose logs --tail=50 promtail
```

Sprawdź, czy Promtail widzi konfigurację:

```bash
docker compose exec promtail promtail -config.file=/etc/promtail/config.yml -check-syntax
```

W Grafanie w `Explore` testuj zapytania:

```logql
{job="decoy-web"}
```

```logql
{job="decoy-web", service="http"}
```

```logql
{job="opencanary", service="http"}
```

Jeżeli `{job="decoy-web"}` działa, ale panele są puste, zwiększ zakres czasu z `Last 5 minutes` na `Last 15 minutes`.

Jeżeli po zmianie konfiguracji dalej widzisz stare panele, przeładuj kontenery:

```bash
docker compose up -d --force-recreate decoy-web promtail grafana
```

Jeżeli OpenCanary nie pokazuje logów HTTP, ale `decoy-web` pokazuje logi, demo nadal działa: NGINX zapisuje metodę, ścieżkę, user-agent i POST body do `logs/nginx/access.log`, a Promtail wysyła to do Loki.

## 11. Fallback ngrok

Jeżeli Tailscale Serve/Funnel nie działa:

```bash
cp .env.example .env
```

Wpisz token w `.env`:

```text
NGROK_AUTHTOKEN=<TWÓJ_TOKEN>
```

Uruchom:

```bash
docker compose --profile ngrok up -d ngrok
docker compose logs -f ngrok
```

## 12. Pliki projektu

| Plik | Rola |
| :--- | :--- |
| `docker-compose.yml` | Wszystkie kontenery i sieć `honeypot_net` |
| `decoy-web/index.html` | Fałszywa strona WWW |
| `decoy-web/nginx.conf` | Proxy `/login`, bait URL-e, JSON access log |
| `opencanary/opencanary.conf` | Konfiguracja OpenCanary |
| `promtail/config.yml` | Scrape logów Cowrie, OpenCanary, NGINX |
| `grafana/dashboards/honeypot_dashboard.json` | Dashboard SIEM |
| `simulate_attack.sh` | Lokalna i zewnętrzna symulacja ataku |
| `deploy/setup.sh` | Idempotentny start stacka i Tailscale Serve |
| `.env.example` | Szablon tokenu ngrok |

---

# IoT Honeypot Stack - Raspberry Pi

This is a Raspberry Pi honeypot demo stack for a controlled academic attack scenario. It collects and visualizes attacks against SSH/Telnet, FTP, HTTP, MySQL, VNC, and a public fake web page exposed through Tailscale Serve/Funnel.

Do not use real credentials. The attacker should use only test passwords from `rockyou_small.txt`.

## Architecture

Services:

| Service | Role | Port |
| :--- | :--- | :--- |
| `cowrie` | SSH/Telnet honeypot | `2222`, `2223` |
| `opencanary` | FTP/HTTP/MySQL/VNC honeypot | `21`, `8082`, `3306`, `5900` |
| `decoy-web` | Fake NGINX web page | `80` |
| `loki` | Log aggregation | `3100` |
| `promtail` | Log shipper | no exposed port |
| `grafana` | SIEM dashboard | `3000` |
| `uptime-kuma` | Service monitoring | `3001` |
| `ngrok` | Public tunnel fallback | Compose profile `ngrok` |

Main web flow:

```text
Attacker -> public Tailscale URL -> RPi:80 -> decoy-web/NGINX
                                             -> /login proxied to OpenCanary:8080
                                             -> NGINX JSON log in logs/nginx/access.log
                                             -> OpenCanary log in logs/opencanary/opencanary.log
                                             -> Promtail -> Loki -> Grafana
```

## Quick Start

On the Raspberry Pi:

```bash
cd ~/honeypot
docker compose up -d
docker compose ps
```

Grafana:

```text
http://localhost:3000
user: admin
password: admin
```

## External Attack Demo

### Roles

| Role | Responsibility |
| :--- | :--- |
| Raspberry Pi | Runs containers and exposes the fake web page through Tailscale |
| Admin laptop | Connects to the RPi and monitors Grafana/logs |
| Attacker | Receives the public URL and runs browser, curl, and Hydra tests |

## 1. Raspberry Pi setup

```bash
cd ~/honeypot
docker compose up -d
docker compose ps
```

Local web check:

```bash
curl -I http://localhost
curl http://localhost/.env
tail -n 5 logs/nginx/access.log
tail -n 5 logs/opencanary/opencanary.log
```

## 2. Expose the web page through Tailscale

Enable Serve/Funnel in the Tailscale admin panel, then run on the RPi:

```bash
tailscale serve --bg http://localhost:80
tailscale serve status
tailscale serve status | grep "https://" >> Tailscale_adres.txt
cat Tailscale_adres.txt
```

Example:

```text
https://pi-user.tail8a7b69.ts.net
```

You can also run:

```bash
./deploy/setup.sh
```

## 3. Admin

SSH to the RPi:

```bash
ssh pi@<TAILSCALE_IP_RPI>
```

Optional Grafana tunnel:

```bash
ssh -L 3000:localhost:3000 pi@<TAILSCALE_IP_RPI>
```

Open on the laptop:

```text
http://localhost:3000
```

Use:

```text
Time range: Last 5 minutes
Refresh: 5s
```

Important panels:

| Panel | Meaning |
| :--- | :--- |
| `Logi Ataków w Czasie Rzeczywistym (Live)` | Raw Cowrie, OpenCanary, and NGINX events |
| `Top Attacked Web Paths` | Most requested bait URLs |
| `Web Login Attempts` | Username/password values sent to `/login` |
| `Attacker User-Agents` | Hydra, curl, browsers, scanners |
| `Attack Timeline (All Services)` | SSH + HTTP + FTP + MySQL timeline |

## 4. Attacker browser test

The attacker receives:

```text
https://pi-user.tail8a7b69.ts.net
```

They open the URL and try test passwords such as:

```text
admin
password
student
test123
```

The fake form posts to:

```text
/login
```

The admin should see the event in Grafana.

## 5. Attacker curl tests

```bash
PUBLIC_URL="https://pi-user.tail8a7b69.ts.net"

curl -k "$PUBLIC_URL/"
curl -k "$PUBLIC_URL/dydaktyka-g/materialy-dla-studentow"
curl -k "$PUBLIC_URL/.env"
curl -k "$PUBLIC_URL/wp-login.php"
curl -k "$PUBLIC_URL/phpmyadmin"
curl -k "$PUBLIC_URL/config.php"
curl -k "$PUBLIC_URL/backup.zip"
curl -k "$PUBLIC_URL/api/v1/users"
```

Manual login attempt:

```bash
curl -k -X POST "$PUBLIC_URL/login" \
  -d "username=admin&password=test123" \
  -A "Mozilla/5.0 (compatible; scanner)"
```

## 6. Attacker Hydra HTTP POST

Recommended command for the public Tailscale HTTPS URL:

```bash
hydra -I -l admin -P rockyou_small.txt \
  pi-user.tail8a7b69.ts.net https-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 443
```

Meaning:

| Part | Meaning |
| :--- | :--- |
| `-I` | ignores an existing `hydra.restore` file |
| `-l admin` | fixed test username |
| `-P rockyou_small.txt` | password list |
| `https-post-form` | Hydra HTTPS form module |
| `/login:username=^USER^&password=^PASS^:Invalid` | endpoint, POST body, failure marker |
| `-s 443` | HTTPS port exposed by Tailscale |

For plain HTTP:

```bash
hydra -I -l admin -P rockyou_small.txt \
  <HOST_OR_IP> http-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 80
```

## 7. SSH Cowrie attack

Tailscale Serve exposes the web page. Cowrie on `2222` must be reachable separately, for example through LAN, Tailscale IP, port forwarding, or a TCP tunnel.

```bash
hydra -I -l admin -P rockyou_small.txt ssh://<RPI_IP> -s 2222 -t 4
```

Manual test:

```bash
ssh root@<RPI_IP> -p 2222
```

## 8. Simulation script

Local:

```bash
./simulate_attack.sh localhost 2222
```

External URL:

```bash
./simulate_attack.sh https://pi-user.tail8a7b69.ts.net 2222
```

## 9. Presentation sequence

1. Show containers on the RPi:

```bash
docker compose ps
```

2. Show the public URL:

```bash
tailscale serve status
```

3. Open Grafana on the admin laptop.

4. The attacker opens the public URL and enters test passwords.

5. The attacker runs:

```bash
curl -k https://pi-user.tail8a7b69.ts.net/.env
curl -k https://pi-user.tail8a7b69.ts.net/wp-login.php
hydra -I -l admin -P rockyou_small.txt \
  pi-user.tail8a7b69.ts.net https-post-form \
  "/login:username=^USER^&password=^PASS^:Invalid" -s 443
```

6. The admin shows Grafana panels with paths, login attempts, user-agents, timeline, and raw logs.

## 10. Troubleshooting `No data` in Grafana

Generate fresh traffic:

```bash
PUBLIC_URL="https://pi-user.tail8a7b69.ts.net"

curl -k "$PUBLIC_URL/.env"
curl -k -X POST "$PUBLIC_URL/login" \
  -d "username=admin&password=test123" \
  -A "curl-test"
```

Check NGINX logs:

```bash
tail -n 20 logs/nginx/access.log
```

If there are no entries, the issue is before NGINX: Tailscale Serve, URL, port 80, or the `decoy-web` container.

Check containers:

```bash
docker compose ps
docker compose logs --tail=50 decoy-web
docker compose logs --tail=50 promtail
```

Explore queries in Grafana:

```logql
{job="decoy-web"}
```

```logql
{job="decoy-web", service="http"}
```

```logql
{job="opencanary", service="http"}
```

If the dashboard still uses old queries after a config change:

```bash
docker compose up -d --force-recreate decoy-web promtail grafana
```

If OpenCanary HTTP is empty but `decoy-web` logs are present, the web demo still works because NGINX records method, path, user-agent, and POST body in JSON logs.

## 11. ngrok fallback

```bash
cp .env.example .env
```

Set:

```text
NGROK_AUTHTOKEN=<YOUR_TOKEN>
```

Run:

```bash
docker compose --profile ngrok up -d ngrok
docker compose logs -f ngrok
```
