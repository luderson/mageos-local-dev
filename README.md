# MageOS Docker Environment

Dockerized environment for running [MageOS](https://mage-os.org/) (community fork of Magento Open Source),
configured via `setup.sh` / `.env`.

## Prerequisites

One-time host setup, before running `./setup.sh`. Covers macOS, Linux (Ubuntu/Debian, Fedora, Arch), and
WSL2 — pick the sub-bullet for your platform under each step.

1. **Docker**, with the Compose v2 plugin (`docker compose version` must work).

   - **macOS**: install [Docker Desktop](https://www.docker.com/products/docker-desktop/), or
     `brew install --cask docker`.
   - **Ubuntu / Debian / Fedora**: use Docker's official convenience script — it installs Engine and the
     Compose v2 plugin together, avoiding distros' older bundled `docker.io`-style packages that sometimes
     ship without the v2 plugin:

     ```bash
     curl -fsSL https://get.docker.com | sh
     ```

   - **Arch**:

     ```bash
     sudo pacman -S docker docker-compose
     ```

   - **Ubuntu / Debian / Fedora / Arch (native Linux only)**: `setup.sh` runs every `docker`/`docker compose`
     command as your normal user, never with `sudo`, so add yourself to the `docker` group, then log out and
     back in (or run `newgrp docker`) for it to take effect:

     ```bash
     sudo usermod -aG docker "$USER"
     ```

   - **WSL2**: install Docker Desktop on Windows and enable WSL2 integration for this distro (Docker Desktop
     Settings → Resources → WSL Integration). If `docker version` reports "command not found" after a WSL
     restart, Docker Desktop itself has stopped on the Windows side (check with `wsl.exe -l -v` — the
     `docker-desktop` distro will show `Stopped`). Start Docker Desktop from Windows and wait for it to
     finish initializing before retrying.

2. **mkcert**, used to issue a browser-trusted local TLS certificate.

   - **macOS**: `brew install mkcert`
   - **Ubuntu / Debian (including WSL2, which runs Ubuntu)**: `sudo apt-get install -y mkcert`
   - **Fedora**: `sudo dnf install mkcert`
   - **Arch**: `sudo pacman -S mkcert`

3. **Install the mkcert local CA as your normal user — do NOT use `sudo` for this step, on any platform:**

   ```bash
   mkcert -install
   ```

   `mkcert -install` creates its local CA under `$HOME/.local/share/mkcert` for whichever user runs it, then
   elevates via `sudo` internally only for the specific step that needs root (adding the CA to the system
   trust store). Running `sudo mkcert -install` instead creates the CA under `/root/.local/share/mkcert`,
   which is a *different* CA than the one your regular user's `mkcert -CAROOT` points to — `setup.sh` (run
   as your normal user) will then generate its own new CA and fail trying to install it system-wide without
   a terminal to prompt for the password. This applies on macOS and Linux too, not just WSL — if it happens,
   just re-run `mkcert -install` as yourself.

   **WSL2 only** — the step above only trusts the cert for tools running *inside* WSL. A browser running on
   Windows itself has no knowledge of it, since Windows keeps its own separate certificate store. To make a
   Windows browser trust it too: find the CA's location with `mkcert -CAROOT` inside WSL, then in Windows
   Explorer navigate to that path (`\\wsl.localhost\<distro-name>\...`), double-click `rootCA.pem`, and walk
   through "Install Certificate" → Local Machine → "Place all certificates in the following store" → Trusted
   Root Certification Authorities.

   `openssl` is also required (used to generate random passwords) but is preinstalled on virtually every
   macOS/Linux/WSL system.

4. **Hosts file entry**, so your browser can resolve the local domain. `setup.sh` asks for a base domain
   (default `mageos`, giving `mageos.local`) and Traefik routes `https://<base-domain>` (storefront/admin)
   and `https://mail.<base-domain>` (Mailpit) to the stack — but nothing adds the DNS/hosts entry for you.
   Substitute your own base domain below if you didn't use the default.

   - **macOS / Linux**: add to `/etc/hosts` directly (needs `sudo` to edit):

     ```text
     127.0.0.1 mageos.local mail.mageos.local
     ```

   - **WSL2**: add the entry to **Windows'** hosts file, not the WSL distro's `/etc/hosts` (WSL regenerates
     its own on every restart, so edits there don't stick — see `/etc/wsl.conf`'s `generateHosts` note in
     that file if you want to disable that). Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator
     and add the same line as above.

## Quick start

```bash
./setup.sh
```

Interactively prompts for configuration (or reuses an existing `.env`), provisions the local TLS cert,
optionally bootstraps a fresh MageOS install into `./src`, then brings the stack up.

## Troubleshooting

**Traefik can't reach the Docker API / storefront returns 404, `docker compose logs traefik` shows
`Error response from daemon: ""` (empty error)** — hit during this project's own development: Docker Engine
29 raised its minimum supported client API version, and Traefik releases `v3.1.x` and earlier hardcode an
outdated one, so the connection silently fails. Already fixed here by pinning `traefik:v3.7.5` (which
auto-negotiates the API version) in `docker-compose.yml`. If you hit this anyway — e.g. after manually
pinning an older Traefik tag — bump the version back up to `v3.6.1` or later.
