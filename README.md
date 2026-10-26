<div align="center">

# 🍯 Honeypot

**IoT Security Lab on a Raspberry Pi**

[![Status](https://img.shields.io/badge/status-demonstration-blue.svg)](https://github.com/Niutaq/Honeypot)
[![Platform](https://img.shields.io/badge/platform-Raspberry_Pi-c51a4a?logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com/)
[![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)

</div>

A self-contained honeypot stack that turns a Raspberry Pi into a multi-service trap for SSH, FTP, HTTP, MySQL, and VNC attacks — with a realistic university-themed decoy website exposed to the internet via Tailscale Funnel. Every interaction is captured, shipped to Loki, and visualized in a pre-built Grafana SIEM dashboard. Designed for **controlled academic cybersecurity labs**, not production threat intelligence.

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Architecture & Tech Stack](#architecture--tech-stack)
- [Security by Design](#security-by-design)
- [Quick Start](#quick-start)
- [Attack Scenarios](#attack-scenarios)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Security & Contributing](#security--contributing)
- [License](#license)

---

## Problem Statement

Teaching offensive and defensive cybersecurity requires a live target — but giving students access to real infrastructure is irresponsible, and cloud-hosted honeypots cost money and lack physicality. Students need to see *the full kill chain*: reconnaissance → exploitation attempt → log ingestion → SIEM visualization — running on hardware they can touch.

**Honeypot solves this by:**

- **Emulating 6+ network services** (SSH, Telnet, FTP, HTTP, MySQL, VNC) on a single \$35 board — attackers can't tell it from a misconfigured campus server
- **Serving a pixel-perfect decoy website** that mimics a real Polish university student portal, complete with fake `.env` files, `wp-login.php`, `phpMyAdmin`, and credential-harvesting login forms
- **Capturing every interaction as structured JSON** — login attempts, command inputs, HTTP paths, User-Agents, POST bodies — with zero manual parsing
- **Shipping all telemetry to a Grafana SIEM** (via Promtail → Loki) with a pre-provisioned dashboard that works out of the box
- **Exposing the decoy publicly** through Tailscale Serve/Funnel with an ngrok fallback — no port forwarding, no dynamic DNS

---

## Architecture & Tech Stack

| Component | Technology | Role |
|:----------|:-----------|:-----|
| SSH/Telnet trap | [![Cowrie](https://img.shields.io/badge/Cowrie-latest-yellow)](https://github.com/cowrie/cowrie) | Medium-interaction honeypot; emulates a Raspbian OpenSSH 8.4 shell with TTY logging |
| Multi-service trap | [![OpenCanary](https://img.shields.io/badge/OpenCanary-latest-orange)](https://github.com/thinkst/opencanary) | FTP, HTTP, MySQL, VNC, SNMP listeners with JSON alerting |
| Decoy website | [![NGINX](https://img.shields.io/badge/NGINX-Alpine-009639?logo=nginx)](https://hub.docker.com/_/nginx) | University portal clone with credential capture and canary path mirroring |
| Log aggregation | [![Loki](https://img.shields.io/badge/Loki-3.0.0-F46800?logo=grafana)](https://grafana.com/oss/loki/) | Lightweight log backend — no Elasticsearch cluster needed |
| Log shipper | [![Promtail](https://img.shields.io/badge/Promtail-3.0.0-F46800?logo=grafana)](https://grafana.com/docs/loki/latest/send-data/promtail/) | Tails Cowrie, OpenCanary, and NGINX JSON logs with field extraction pipelines |
| SIEM dashboard | [![Grafana](https://img.shields.io/badge/Grafana-latest-F46800?logo=grafana)](https://grafana.com/) | Pre-provisioned dashboard: live attack feed, top paths, captured credentials, User-Agent breakdown |
| Service monitoring | [![Uptime Kuma](https://img.shields.io/badge/Uptime_Kuma-1-5CDD8B)](https://github.com/louislam/uptime-kuma) | Health checks for every container in the stack |
| Public tunnel | [![Tailscale](https://img.shields.io/badge/Tailscale-Funnel-4C8BF5)](https://tailscale.com/kb/1223/funnel) | Zero-config HTTPS exposure; ngrok as optional fallback |

### Why this stack?

- **Loki over Elasticsearch** — an RPi 4 has 1–8 GB RAM; Loki's label-indexed design uses an order of magnitude less memory than an ELK stack while keeping LogQL query power.
- **Cowrie + OpenCanary instead of a single honeypot** — Cowrie gives deep SSH/Telnet interaction (fake filesystem, command recording); OpenCanary covers breadth (FTP, MySQL, VNC, SNMP). They complement, not overlap.
- **NGINX as the decoy frontend** — allows structured JSON access logs with POST body capture, canary path mirroring to OpenCanary via `mirror`, and static HTML serving — all without application code.
- **Tailscale Funnel over raw port forwarding** — automatic HTTPS, no home router configuration, auditable access. Ngrok profile kept as a fallback for networks where Tailscale is blocked.
- **Static IPs on a bridge network** (`172.28.0.0/24`) — deterministic container addressing for firewall rules and Promtail scrape targets without DNS dependencies.

---

## Security by Design

This is a *honeypot* — it is designed to be attacked. The security posture focuses on **containment**, not prevention.

- **Isolation** — every service runs in its own container on an isolated Docker bridge network with static IPs; no host networking, no privileged mode (only `NET_BIND_SERVICE` for port 21)
- **No real data** — all credentials in `userdb.txt` and the decoy website are synthetic; `.env`, `config.php`, and `backup.zip` serve fake but realistic-looking content designed to waste attacker time
- **Controlled exposure** — Tailscale Funnel provides identity-aware tunneling; the ngrok fallback requires an auth token; neither exposes the host SSH or Grafana ports

---

## Quick Start

### Prerequisites

| Tool | Version | Notes |
|:-----|:--------|:------|
| Docker Engine + Compose v2 | ≥ 24.x | `docker compose` (not `docker-compose`) |
| Tailscale | any | Optional — for public exposure via Funnel |
| sshpass, curl, hydra | any | Optional — for running attack simulations from another machine |

### 1. Clone and deploy

```bash
git clone git@github.com:Niutaq/Honeypot.git
cd Honeypot

# Optional: set ngrok token for fallback tunnel
cp .env.example .env
# edit .env → NGROK_AUTHTOKEN=...

# One-shot deploy (creates dirs, pulls images, starts stack, configures Tailscale)
./deploy/setup.sh
```

### 2. Verify the stack

```bash
docker compose ps          # all 7 services should be Up
curl -s http://localhost   # decoy website HTML
```

### 3. Open Grafana

Navigate to `http://<rpi-ip>:3000` — default credentials: `admin` / `admin`.
The **Honeypot IoT Security Dashboard** is pre-provisioned via `grafana/provisioning/`.

### 4. Expose publicly (optional)

```bash
# Tailscale (recommended)
tailscale serve --bg http://localhost:80

# Ngrok fallback
docker compose --profile ngrok up -d ngrok
```

### Available Commands

| Command | Description |
|:--------|:------------|
| `docker compose up -d` | Start the full stack |
| `docker compose ps` | Check container health |
| `docker compose logs -f cowrie` | Stream Cowrie SSH logs |
| `docker compose --profile ngrok up -d ngrok` | Start ngrok tunnel fallback |
| `./deploy/setup.sh` | Idempotent full deploy (dirs + pull + up + Tailscale) |
| `./simulate_attack.sh <target> [ssh-port]` | Run SSH brute-force + web probing simulation |
| `./launch_attack.sh` | Parallel Hydra SSH + HTTP + path scan (uses `rockyou_small_v2.txt`) |

---

## Attack Scenarios

The repo includes ready-to-run scripts for generating realistic telemetry during a lab session:

| Scenario | Command | What it does |
|:---------|:--------|:-------------|
| Full simulation | `./simulate_attack.sh <target>` | SSH brute-force (sshpass) → HTTP login form spray → path scan (`/admin`, `/.env`, `/wp-login.php`, …) |
| Parallel Hydra | `./launch_attack.sh` | Concurrent Hydra on SSH:2222 + HTTPS POST + continuous path scanner |
| Browser | Open the public URL | Manual exploration — the decoy site looks like a real university portal |
| Targeted curl | `curl -X POST <url>/login -d "username=admin&password=test123"` | Single credential capture test |

---

## Known Limitations

- **Not a production honeypot** — Cowrie's emulated shell is detectable by sophisticated attackers (limited command set, no real kernel). This is for teaching, not threat intel.
- **Single-board bottleneck** — under heavy brute-force (Hydra at `-t 16`), an RPi 4 with 2 GB RAM will saturate. Loki may drop writes if Promtail queues overflow.
- **No alerting pipeline** — Grafana dashboards are passive; there are no alert rules, PagerDuty integrations, or automated IP blocking.
- **Cowrie SSH on port 2222** — not port 22. On an RPi where real SSH runs on 22, this is intentional but reduces realism. Port remapping at the host firewall level is possible but not configured by default.
- **OpenCanary SSH/Telnet disabled** — to avoid conflicts with Cowrie. This means OpenCanary's SSH detection capabilities are unused.
- **Log rotation** — Docker JSON log driver is capped at 10 MB per container, but Cowrie/OpenCanary/NGINX log files in `./logs/` grow unbounded. Long-running deployments need manual cleanup or logrotate.

---

## Roadmap

- [x] Cowrie SSH/Telnet honeypot with custom `userdb.txt`
- [x] OpenCanary multi-service trap (FTP, HTTP, MySQL, VNC, SNMP)
- [x] Realistic decoy university website with credential capture
- [x] Canary paths: `.env`, `config.php`, `backup.zip`, `wp-login.php`, `phpmyadmin`, `/api/v1/users`
- [x] Structured JSON logging from all services
- [x] Promtail pipelines with field extraction (IPs, usernames, passwords, User-Agents)
- [x] Pre-provisioned Grafana SIEM dashboard
- [x] Uptime Kuma service health monitoring
- [x] Tailscale Funnel exposure + ngrok fallback
- [x] Idempotent deploy script (`deploy/setup.sh`)
- [x] Attack simulation scripts (sshpass, curl, Hydra)
- [ ] Grafana alerting rules (Slack/email on brute-force threshold)
- [ ] GeoIP enrichment for attacker source visualization
- [ ] Automated log rotation for `./logs/` directory
- [ ] Fail2ban integration for realistic defensive response
- [ ] MITRE ATT&CK mapping on the Grafana dashboard

---

## Security & Contributing

> [!CAUTION]
> This project is designed for **controlled academic environments only**. Deploying a honeypot on a network you do not own or without authorization is illegal in most jurisdictions.

- Security issues → [SECURITY.md](SECURITY.md)
- Contributions → [CONTRIBUTING.md](CONTRIBUTING.md)

---

## License

Educational demonstration project. See repository for terms.

---

<div align="center">
<sub>Built for cybersecurity labs at Politechnika Rzeszowska · Katedra Elektrotechniki i Podstaw Informatyki</sub>
</div>
