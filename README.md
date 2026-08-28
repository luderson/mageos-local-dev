# MageOS Docker Environment

Dockerized environment for running [MageOS](https://mage-os.org/) (community fork of Magento Open Source),
configured via `setup.sh` / `.env`.

## Prerequisites

One-time host setup, before running `./setup.sh`:

1. **Docker Desktop**, with WSL2 integration enabled for this distro.
   - If `docker version` reports "command not found" after a WSL restart, Docker Desktop itself has stopped
     on the Windows side (check with `wsl.exe -l -v` — the `docker-desktop` distro will show `Stopped`).
     Start Docker Desktop from Windows and wait for it to finish initializing before retrying.
2. **mkcert**, used to issue a browser-trusted local TLS certificate:

   ```bash
   sudo apt-get install -y mkcert
   ```

3. **Install the mkcert local CA as your normal user — do NOT use `sudo` for this step:**

   ```bash
   mkcert -install
   ```

   `mkcert -install` creates its local CA under `$HOME/.local/share/mkcert` for whichever user runs it, then
   elevates via `sudo` internally only for the specific step that needs root (adding the CA to the system
   trust store). Running `sudo mkcert -install` instead creates the CA under `/root/.local/share/mkcert`,
   which is a *different* CA than the one your regular user's `mkcert -CAROOT` points to — `setup.sh` (run
   as your normal user) will then generate its own new CA and fail trying to install it system-wide without
   a terminal to prompt for the password. If this happens, just re-run `mkcert -install` as yourself.

   `openssl` is also required (used to generate random passwords) but is preinstalled on virtually every
   Linux/WSL distro.

4. **Hosts file entry**, so your browser can resolve the local domain. `setup.sh` asks for a base domain
   (default `mageos`, giving `mageos.local`) and Traefik routes `https://<base-domain>` (storefront/admin)
   and `https://mail.<base-domain>` (Mailpit) to the stack — but nothing adds the DNS/hosts entry for you.

   On WSL2, add the entry to **Windows'** hosts file, not the WSL distro's `/etc/hosts` (WSL regenerates its
   own on every restart, so edits there don't stick — see `/etc/wsl.conf`'s `generateHosts` note in that
   file if you want to disable that). Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator and add:

   ```text
   127.0.0.1 mageos.local mail.mageos.local
   ```

   (Substitute your own base domain if you didn't use the default.) On native Linux/macOS, add the same line
   to `/etc/hosts` directly.

## Quick start

```bash
./setup.sh
```

Interactively prompts for configuration (or reuses an existing `.env`), provisions the local TLS cert,
optionally bootstraps a fresh MageOS install into `./src`, then brings the stack up.
