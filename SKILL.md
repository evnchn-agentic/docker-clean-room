---
name: docker-clean-room
description: Use when you must prove something works FROM A CLEAN BASE — testing whether an install.sh / setup / bootstrap runs on a fresh machine, verifying a tool self-bootstraps its own runtime (e.g. "does it work with NO Python installed?"), reproducing a from-scratch build, or checking a dependency/lockfile PR really resolves from nothing. Fires especially when tempted to hunt for, modify, or otherwise risk a real shared node/host for a throwaway test (e.g. uninstalling something to fake a condition), or when asked to "find a machine without X". NOT for isolating execution for safety alone (see When NOT).
---

# docker-clean-room

## Overview

To prove something works **from nothing**, run it in a **disposable Docker container** that starts as the bare base you're claiming to support — then `docker exec` into it, **bash-piping** commands like you would any shell. Toss it when done.

**Core principle:** a clean-room test is only honest if the host's tools *cannot leak in*. Your host has Python, node, uv, brew, a dozen dev tools on `$PATH`. Testing "does it install with no Python?" on the host — or in the native OS sandbox, which **runs on the host toolchain** — is testing a lie. You need a **fresh base whose contents you fully control**. A VM, chroot, or Nix/Guix shell also qualify; a throwaway container is just the cheapest such base that's *actually* Python-free.

## When to use

- Testing a colleague's `install.sh` / setup / one-liner on a "fresh machine".
- Proving a bootstrapper self-installs its runtime (`uv`/`nvm`/`rustup`/`mise` pulling their own Python/node/toolchain with none preinstalled).
- Verifying a **dependency/lockfile/pin PR** resolves from a clean base — installing on your already-warm host proves nothing (see the `uv sync` / stubbed-module traps in CLAUDE.md's outward-work rules).
- Reproducing a from-scratch build to catch "works on my machine".
- You catch yourself about to **SSH to a real node**, uninstall something, or otherwise **use/risk shared hardware** for a throwaway test. Don't hunt for a machine that lacks X — `docker run` an image that never had X.

## When NOT to use (reach for the right tool instead)

| You actually need… | Use | Why not this skill |
|---|---|---|
| **Execution *safety*** (don't let a build/test wreck the host) but the host toolchain is fine | native CC `/sandbox` | `/sandbox` is **not a clean base** — it runs Bash *on the host toolchain*, so it can't make "no Python" true (the technical reason it's wrong here). Separately, its *safety* payoff depends on permission mode: it mostly removes prompts for accept-edits/manual-approval users, and adds little on auto/bypass where incompatible commands just fall back to unsandboxed auto-exec |
| The host's **real toolchain / GPU / hardware / exact OS** under test | the host or the real node | a container is a different base by design; that's the whole point |
| Parallel isolated **standing dev environments** for agents | more `docker run` boxes, or Dagger `container-use` if you want managed per-agent envs | `container-use` targets *standing parallel dev envs*, not throwaway verification, and routes work through an MCP layer that's higher-friction for ad-hoc stdin/heredoc piping than plain `docker exec` — a preference, not a hard limit |

## The mechanic (bash-pipeable `docker exec`)

The realization that makes this clean: **Claude Code's Read/Edit/Write run on the host; only Bash needs to reach into the box.** So keep the agent (and all orchestration — SSH, memory, dashboard) on the host, and send only the *dirty execution* into a tossable container.

```bash
# 1. Launch a box that IS the clean base you claim to support.
#    Pick the image to MATCH the machine you're simulating — and deliberately
#    OMIT the thing under test. Proving "no Python"? Use a base without it.
#    Publish any port you'll reach from the host/LAN (-p) AT run time.
#    Use a DISTINCTIVE name — `docker rm -f <name>` later deletes WHATEVER has
#    that name, so never a bare `box` that might collide with a real container.
BOX=cleanroom-$$        # $$ = shell PID; unique per run, safe for parallel tests
docker run -d --name "$BOX" -p 7777:7777 debian:bookworm-slim sleep infinity

# 2. Provision only what a realistic target already has (curl, git) — NOT the
#    thing you're testing the bootstrap of. Note: `git` pulls transitive tooling;
#    for a strict "only curl present" target, install less. State your preconditions.
docker exec "$BOX" bash -c 'apt-get update -qq && apt-get install -y -qq curl ca-certificates git'

# 3. Canary the absence — this proves python3 isn't on PATH, NOT that no
#    interpreter exists anywhere; still the honest pre-check.
docker exec "$BOX" bash -c 'command -v python3 || echo "python3 not on PATH ✓"'

# 4. Run the real thing. `-i` keeps stdin open so you can BASH-PIPE into the box:
#    answer stdin-reading prompts, feed heredocs, stream files. (Piping does NOT
#    satisfy installers that read /dev/tty or need a real TTY — see caveats.)
docker exec "$BOX" bash -c 'cd /root && git clone <repo> && cd repo && git checkout <tag>'
printf 'y\n' | docker exec -i "$BOX" bash -c 'cd /root/repo && ./install.sh'   # pipe "y" to a stdin prompt

# 5. Observe from the host (published port), then TOSS it. Tossable is the point.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:7777/
docker rm -f "$BOX"
```

## Caveats learned in the field

- **Arch:** by default Docker resolves the image for your *host's* arch (aarch64 on Apple Silicon). Proving a mechanism on ARM ≠ proving it on a real x86 laptop — **say which arch you tested.** `--platform linux/amd64` forces x86 but needs QEMU/binfmt emulation (Docker Desktop bundles it): much slower, and it fails if emulation isn't available.
- **libc:** `alpine` is musl, not glibc. Bootstrappers that fetch prebuilt glibc binaries (uv's CPython, many native wheels, node) can misbehave or fail on musl — a *second* confounding variable. For a faithful "normal laptop" clean-room prefer a glibc slim base (`debian:*-slim`, `ubuntu:*`) unless musl is what you're actually testing.
- **Reachability / QR / phone:** a service reachable via `-p` must bind **`0.0.0.0`** inside the container — `-p` cannot forward to a service bound to `127.0.0.1` *inside* the box. Even then the app's own interface auto-detect may advertise the bridge IP (`172.x`/`10.x`), so a QR / "network URL" can point somewhere unreachable while the server is up. Verify from a *second device*; don't assume.
- **Not a security boundary:** a plain container is isolation-for-tidiness, not a hostile-code jail — and **Docker daemon access is effectively host-root.** `--privileged`, host networking, host bind-mounts, or mounting `/var/run/docker.sock` make it strictly worse. Don't run untrusted code and call it safe.
- **Always tear down** (`docker rm -f "$BOX"`). A lingering "temporary" box is how the disposable estate stops being disposable.

## Common mistakes

| Mistake | Fix |
|---|---|
| Testing "from nothing" on the host (or native `/sandbox`) | Host toolchain leaks in; only a fresh image makes the absence real |
| Hunting for / arranging a real node that "lacks X" | `docker run` an image that never had X — seconds, zero risk, no shared-hardware claim |
| Forgetting `-i` and wondering why you can't answer a prompt | `docker exec -i box …` and bash-pipe the input |
| Publishing no port, then "can't reach it" | `-p host:container` at `run` time (can't be added after) |
| Leaving the box running | `docker rm -f "$BOX"` — it's a clean-*room*, not a tenant |
| Reusing a bare name like `box` | `docker rm -f box` deletes whatever has that name — use a distinctive `cleanroom-$$` |

## ⚠️ BRICK — not yet pressure-tested; enforcement value is modest

Distilled 2026-07-08 from a live case (testing a colleague's uv-bootstrap install.sh) + a recovered prior session (2026-07-05: the docker-exec / execution-vs-orchestration split, never captured).

**Honest baseline (measured — matters for what this skill is/isn't):** in the wild a handoff agent *defaulted to a real shared node* ("find/arrange one without Python"). But a **clean cross-lineage control** (Codex/GPT-5, with neither this CLAUDE.md nor this skill) picked a disposable `debian:slim` container *spontaneously*, ruling out host + real node on its own reasoning. So the **container *choice* is NOT where capable agents fail** — the wild failure traces to a *leading* "use a node" task framing, not an inability to think of containers. (Same-session Claude subagents can't RED-test this: they auto-load this skill + CLAUDE.md and just echo it — 4/4 followed it correctly, which shows the skill is *clear*, not that it's *needed*.)

**⇒ Value is real but specific — don't oversell it.** Capable agents already pick a container for the *choice* itself, so don't sell it as "makes agents pick Docker." What it genuinely earns:
- **Anti-shenanigan guardrail (floor-adjacent) — the enforcement value.** Under a leading *"use one of your nodes / find one without X"* frame (exactly the wild-handoff wording), the tempting move is to SSH a **shared** node and *uninstall/strip* the tool to manufacture the condition — irreversible risk to others' hardware for a throwaway test. "Don't hunt/strip a real node — `docker run` an image that never had X" is a cheap, explicit stop on that destructive branch. Consequences dominate probabilities: worth a guardrail even if most agents wouldn't slip.
- **Reliable trigger** — a registered description fires on the situation; better than hoping each agent reasons its way there.
- **Field caveats the clean control omitted** — arch · musl/glibc · `0.0.0.0`+`-p` reachability · multi-homed QR interface · unique-name teardown · `/dev/tty` piping limit.
- **One solid routing fact** — native `/sandbox` can't make "no Python" true (runs on host toolchain); the rest of the routing is preference, flagged as such.

One clean-lineage control run so far; the open residual is whether a *leading* "use a node" frame still misdirects a capable agent (the wild failure) — needs 5+ reps to quantify. Refine via `/whiteboxing` (ledger: `POLISH.md`).
