# Security Policy

## Scope

This project is a **controlled academic honeypot** — it is *designed* to be attacked in a lab setting. Security reports should focus on risks that break containment or affect the host system.

## Reporting a Vulnerability

If you find a vulnerability that allows:

- **Container escape** from any honeypot service to the host
- **Lateral movement** from the honeypot network (`172.28.0.0/24`) to other Docker networks or the host
- **Credential leakage** of real (non-decoy) data
- **Denial of service** that crashes the RPi host (not just a container)

Please report it by opening a GitHub issue or contacting the maintainer directly.

## Out of Scope

- Attacks against the honeypot services themselves (that's the point)
- Brute-force success against Cowrie/OpenCanary (intentional by design)
- Content of decoy files (`.env`, `config.php`, etc.) — all data is synthetic
