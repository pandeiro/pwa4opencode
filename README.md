# pwa4opencode

Run [opencode](https://opencode.ai) on your phone as a native-feeling PWA.

opencode's web UI already ships everything a PWA needs — manifest, icons, iOS
meta tags. The only missing piece is HTTPS. This repo wires that up on a Mac
with zero custom code: a launchd agent runs `opencode serve`, and Tailscale
exposes it over HTTPS inside your tailnet.

```
phone ──HTTPS──▶ tailscale ──▶ opencode (127.0.0.1:4096)
```

## Requirements

- macOS
- [opencode](https://opencode.ai): `curl -fsSL https://opencode.ai/install | bash`
- [Tailscale](https://tailscale.com) on your Mac and your phone, on the same tailnet

## Setup

```bash
git clone https://github.com/pandeiro/pwa4opencode
cd pwa4opencode
./setup.sh
```

The script detects opencode and tailscale, installs a launchd agent, configures
Tailscale Serve, verifies the PWA manifest is being served, and prints your URL.

On your phone, open that URL and choose **Add to Home Screen**.

## Options

| Flag | Purpose |
|---|---|
| `--opencode PATH` | Explicit path to the opencode binary |
| `--tailscale PATH` | Explicit path to the tailscale CLI |
| `--port N` | Local port for opencode's server (default 4096) |
| `--dry-run` | Detect dependencies and write the env file only |

To require basic auth on the web UI, set a password before running setup:

```bash
OPENCODE_SERVER_PASSWORD=secret ./setup.sh
```

## Stopping / uninstalling

```bash
./stop.sh       # stop the agent
./uninstall.sh  # remove agent + generated files, optionally reset Tailscale Serve
```

## Troubleshooting

- **opencode not found** — pass its location: `./setup.sh --opencode ~/.opencode/bin/opencode`
- **Port already in use** — another opencode is running; stop it or use `--port`
- **Your URL** — `tailscale serve status`
- **Logs** — `opencode.log` / `opencode.err.log` in this directory

## Design notes

Why there's no proxy, no Docker, and no forks: [docs/ADR.md](docs/ADR.md).
