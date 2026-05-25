# IoT Honeypot Stack - Raspberry Pi

[![Project Status](https://img.shields.io/badge/status-demonstration-red.svg)](https://github.com/niutaq/honeypot)

---

## Wersja polska

Projekt demonstracyjny honeypota uruchamianego na Raspberry Pi. Stack zbiera i wizualizuje ataki na usługi SSH/Telnet, FTP, HTTP, MySQL, VNC oraz na fałszywą stronę WWW wystawioną publicznie przez Tailscale Serve/Funnel.

Ten projekt jest przeznaczony do kontrolowanego scenariusza akademickiego. Nie używaj prawdziwych danych logowania. Atakujący powinien używać wyłącznie testowych haseł ze słownika rockyou_small.txt.

### Architektura

Usługi:

| Usługa | Rola | Port |
| :--- | :--- | :--- |
| cowrie | SSH/Telnet honeypot | 2222, 2223 |
| opencanary | FTP/HTTP/MySQL/VNC honeypot | 21, 8082, 3306, 5900 |
| decoy-web | Fałszywa strona WWW na NGINX | 80 |
| loki | Agregacja logów | 3100 |
| promtail | Zbieranie logów do Loki | brak portu |
| grafana | Dashboard SIEM | 3000 |
| uptime-kuma | Monitoring usług | 3001 |
| ngrok | Fallback tunelu publicznego | profil ngrok |

Przepływ WWW:
Atakujący -> publiczny URL Tailscale -> RPi:80 -> decoy-web/NGINX -> /login proxy do OpenCanary:8080 -> log NGINX JSON do logs/nginx/access.log -> log OpenCanary do logs/opencanary/opencanary.log -> Promtail -> Loki -> Grafana

### Szybki Start

Na Raspberry Pi:
```bash
cd ~/honeypot
docker compose up -d
docker compose ps
```

Panel Grafana:
http://pi-user.local:3000 (admin/admin)

### Scenariusze Ataków

1. Atakujący - przeglądarka:
Otwarcie publicznego URL i wpisanie testowych haseł (admin, student, test123). Formularz wysyła POST na /login.

2. Atakujący - curl:
```bash
curl -k "$PUBLIC_URL/.env"
curl -k -X POST "$PUBLIC_URL/login" -d "username=admin&password=test123"
```

3. Atakujący - Hydra HTTP POST:
```bash
hydra -I -l admin -P rockyou_small.txt -s 443 <HOST> https-post-form "/login:username=^USER^&password=^PASS^:Invalid"
```

4. Atakujący - SSH Cowrie:
```bash
ssh root@<IP_RPI> -p 2222
```

### Monitoring i Analiza

Dashboard: Honeypot IoT Security Dashboard
- Logi Ataków w Czasie Rzeczywistym: Surowe zdarzenia.
- Top Attacked Web Paths: Najczęściej odwiedzane ścieżki.
- Web Login Attempts: Przechwycone dane logowania.
- Attacker User-Agents: Narzędzia używane przez atakującego.

### Rozwiązywanie problemów

Jeśli Grafana pokazuje "No data":
1. Sprawdź log NGINX: tail -n 20 logs/nginx/access.log
2. Sprawdź status kontenerów: docker compose ps
3. Sprawdź logi kontenerów: docker compose logs --tail=50 promtail
4. Przeładuj stack: docker compose up -d --force-recreate

---

## English version

A Raspberry Pi honeypot demo stack for a controlled academic attack scenario. It collects and visualizes attacks against SSH/Telnet, FTP, HTTP, MySQL, VNC, and a public fake web page exposed through Tailscale Serve/Funnel.

This project is intended for controlled academic scenarios. Do not use real credentials. Attackers should use only test passwords from rockyou_small.txt.

### Architecture

Services:

| Service | Role | Port |
| :--- | :--- | :--- |
| cowrie | SSH/Telnet honeypot | 2222, 2223 |
| opencanary | FTP/HTTP/MySQL/VNC honeypot | 21, 8082, 3306, 5900 |
| decoy-web | Fake NGINX web page | 80 |
| loki | Log aggregation | 3100 |
| promtail | Log shipper | no port |
| grafana | SIEM dashboard | 3000 |
| uptime-kuma | Service monitoring | 3001 |
| ngrok | Public tunnel fallback | ngrok profile |

Web flow:
Attacker -> public Tailscale URL -> RPi:80 -> decoy-web/NGINX -> /login proxied to OpenCanary:8080 -> NGINX JSON log in logs/nginx/access.log -> OpenCanary log in logs/opencanary/opencanary.log -> Promtail -> Loki -> Grafana

### Quick Start

On the Raspberry Pi:
```bash
cd ~/honeypot
docker compose up -d
docker compose ps
```

Grafana Panel:
http://pi-user.local:3000 (admin/admin)

### Attack Scenarios

1. Attacker - Browser:
Open the public URL and enter test passwords (admin, student, test123). The form posts to /login.

2. Attacker - curl:
```bash
curl -k "$PUBLIC_URL/.env"
curl -k -X POST "$PUBLIC_URL/login" -d "username=admin&password=test123"
```

3. Attacker - Hydra HTTP POST:
```bash
hydra -I -l admin -P rockyou_small.txt -s 443 <HOST> https-post-form "/login:username=^USER^&password=^PASS^:Invalid"
```

4. Attacker - SSH Cowrie:
```bash
ssh root@<IP_RPI> -p 2222
```

### Monitoring and Analysis

Dashboard: Honeypot IoT Security Dashboard
- Live Attack Logs: Raw events.
- Top Attacked Web Paths: Most requested URLs.
- Web Login Attempts: Captured credentials.
- Attacker User-Agents: Identification of attacker tools.

### Troubleshooting

If Grafana shows "No data":
1. Check NGINX logs: tail -n 20 logs/nginx/access.log
2. Check container status: docker compose ps
3. Check container logs: docker compose logs --tail=50 promtail
4. Recreate the stack: docker compose up -d --force-recreate

---

## Nota Prawna / Legal Notice

Projekt wyłącznie do celów edukacyjnych. Nie używaj go do monitorowania prawdziwych systemów bez odpowiedniej autoryzacji.
For educational purposes only. Do not use for monitoring real systems without authorization.
