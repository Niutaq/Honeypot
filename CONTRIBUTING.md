# Contributing

Thanks for your interest in improving this project.

## How to contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes
4. Test locally with `docker compose up -d` on an RPi or x86 machine
5. Open a Pull Request with a clear description of what changed and why

## Areas where help is welcome

- **Grafana alerting rules** — threshold-based alerts for brute-force detection
- **GeoIP enrichment** — MaxMind or IP-API integration in the Promtail pipeline
- **Additional decoy paths** — more realistic web content to increase attacker dwell time
- **Log rotation** — logrotate config or a sidecar container for `./logs/`
- **Documentation** — attack scenario walkthroughs, lab exercise guides

## Guidelines

- Keep the stack runnable on a Raspberry Pi 4 (2 GB RAM minimum)
- No real credentials, domains, or PII in any file
- All new services must use the `honeypot_net` bridge network with a static IP
