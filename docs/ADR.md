# ADR: pwa4opencode design

- **Status:** accepted
- **Date:** 2026-09-01
- **Scope:** macOS orchestration for exposing opencode's web UI as an installable PWA over a tailnet.

## Context

opencode ships a browser-based UI (`opencode serve` / `opencode web`). To
install that UI as a PWA on a phone, three conditions must hold: the app must
be served over HTTPS, the origin must present a valid web app manifest with
usable icons, and iOS requires a resolvable `apple-touch-icon`. The user is on
a Mac, accesses the UI from a phone, and wants the setup to be invisible — a
daemon that survives reboots and repairs itself.

## Decisions

### 1. Serve opencode's responses unmodified; no reverse proxy

The bundled server already satisfies every PWA requirement on its own. Verified
against opencode 1.18.25 served over plain HTTP:

- `/site.webmanifest` is a complete manifest (`id`, `start_url`, `scope`,
  `display: standalone`, maskable 192/512 icons) served as
  `application/manifest+json`.
- Every icon referenced by the manifest and the document (`apple-touch-icon`,
  favicons) resolves with HTTP 200 and correct image dimensions.
- The document head already contains the iOS integration meta tags
  (`apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`,
  `mobile-web-app-capable`, `theme-color`).

A proxy that rewrites responses (e.g., to inject a manifest) would duplicate
upstream behavior and add a process, a failure domain, and buffering concerns
around streaming endpoints, with no user-visible benefit. HTTPS is the only
missing condition, and it is supplied by the transport layer (see decision 5).

Because this couples the repo to upstream behavior, setup performs a post-install
verification: it requests the manifest and one manifest icon plus the
apple-touch-icon from the running server and warns if they do not respond. A
future upstream regression therefore surfaces at install time rather than as a
mysterious "can't install" on the phone. The verification is advisory; the
agent is still installed.

### 2. Headless server mode (`opencode serve`), not `opencode web`

`opencode web` binds the same server and then unconditionally invokes a browser
opener (verified in the upstream CLI source; there is no `--no-open` flag, and
the opener library no longer honors the `BROWSER` environment variable). Under
a restart-on-exit supervisor this would open a browser tab on every restart.
`opencode serve` runs the identical `Server.listen` code path without any GUI
interaction, which is the correct shape for an unattended daemon. Trade-off:
slightly less informative startup output, irrelevant in a log file.

### 3. launchd agent with a generated environment file

launchd agents run with a minimal `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`);
binaries installed by Homebrew, mise, nvm, or opencode's own installer are not
visible at runtime. Resolving binaries by absolute path is therefore mandatory.

- `setup.sh` resolves each dependency once, validates it by executing it
  (`--version` / `version`), and persists the resolved paths plus configuration
  to `pwa4opencode.env` (mode 600, gitignored).
- `run.sh` sources that file and contains no discovery logic of its own; if the
  file is missing it fails with a pointer to `setup.sh`.
- The agent uses `KeepAlive` with `ThrottleInterval` 10; effective crash
  supervision is internal to `run.sh` (see Process supervision semantics).
  The agent logs to files in the project directory.

### 4. Dependency resolution: explicit flag → PATH → common locations

Resolution order per dependency: a `--opencode` / `--tailscale` flag, then
`command -v`, then a scan of well-known install locations (opencode's installer
path `~/.opencode/bin`; Homebrew on ARM and Intel; the Tailscale app bundle).
Candidates are checked for executability, and every resolved binary is validated
by running it — path existence alone accepts broken shims. Flags are the
documented escape hatch for nonstandard layouts (nvm, asdf, custom installs).
`--dry-run` performs resolution and env-file generation without touching
launchd or Tailscale, so the detection half of the script is testable in
isolation.

### 5. Tailscale Serve for TLS and access control

HTTPS with a real certificate (tailnet DNS, automatic issuance and renewal) and
identity-scoped exposure come from `tailscale serve --bg --https=443 <port>` at
zero configuration cost. opencode binds to loopback only, so the exposure
boundary is exactly tailnet membership; the local port is unreachable from the
LAN. For additional isolation from other devices on the tailnet,
`OPENCODE_SERVER_PASSWORD` (upstream's basic-auth mechanism) is passed through
to the agent environment when set at setup time. Tailscale Funnel (public
internet exposure) is out of scope. If the tailscale CLI is absent or `serve`
fails, installation continues and the manual command is printed — the daemon is
useful over localhost even without it.

### 6. Zero custom application code

The repository consists of orchestration scripts only. All PWA behavior,
streaming, session handling, and UI concerns ride on upstream opencode
releases. This minimizes the maintenance surface to: dependency detection,
process supervision, and tunnel configuration — each of which is small,
deterministic, and testable without opencode running.

### 7. Idempotent, reversible installation

`setup.sh` unloads any existing agent before bootstrapping, so it is safe to
re-run (e.g., after changing ports or paths). `uninstall.sh` stops the agent,
removes the plist and generated env file, and optionally resets Tailscale
Serve; because `tailscale serve reset` clears all serve rules machine-wide, it
is gated behind an interactive confirmation.

## Process supervision semantics

Empirically on current macOS, `launchctl bootstrap` can register an agent but
pend its initial `RunAtLoad` spawn indefinitely (`pended nondemand spawn`),
and the same applies to `KeepAlive` respawns. launchd-side spawning is
therefore treated as best-effort only:

- `setup.sh` demands the first spawn explicitly with `launchctl kickstart`
  after bootstrapping, then verifies over HTTP that the server is answering
  before reporting success.
- `run.sh` owns crash supervision: it restarts `opencode serve` with a 10s
  backoff and exits only on `INT`/`TERM`, so a single launchd spawn per login
  session is sufficient. The backoff sleeps in 1-second chunks to keep signal
  handling inside launchd's 5-second exit timeout, so termination never
  orphans the child.
- Before the first start, `run.sh` refuses to run if the configured port is
  already bound and fails loudly instead of crash-looping against an
  occupied socket.

## Constraints and non-goals

- macOS only. Linux equivalents (systemd user units) are welcome but unimplemented.
- One opencode instance per machine; ports default to 4096 and must be free.
- Logs are unrotated files in the project directory.
- Multi-instance or multi-user setups are out of scope.

## Alternatives considered

- **Docker**: adds a VM tax on macOS and image/version management for a
  two-process problem that the OS supervisor already solves.
- **Forking or patching opencode**: couples the repo to upstream internals and
  makes every upstream release a maintenance event.
- **Full reverse proxy (nginx/Caddy) with manifest injection**: only justified
  if upstream lacked PWA support; it does not (decision 1).
- **Tailscale Funnel**: exposes the service to the public internet; unnecessary
  for a personal device and strictly worse for access control.
