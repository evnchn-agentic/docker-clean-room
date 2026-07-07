# docker-clean-room

An agent **skill** (Claude Code / Agent Skills format): to prove something works *from a clean base* —
an `install.sh` on a fresh machine, a tool self-bootstrapping its own runtime ("does it work with **no
Python** installed?"), or a lockfile/dependency change resolving from nothing — spin a **disposable Docker
container** as the clean-room and bash-pipe into `docker exec`, instead of testing on the host (whose
toolchain leaks in) or modifying/stripping a real shared machine to fake the condition.

## Why it exists (the honest version)

Three distinct needs get conflated — and existing tools cover the *outer* two while leaving the **middle empty**:

| Need | Existing tool |
|---|---|
| Isolate execution for *safety* | native `/sandbox` (OS-level, built into Claude Code) |
| **Prove it works from a clean base** — no host tools leak in | **— nothing dedicated — ← this skill** |
| Parallel isolated *dev environments* | Dagger `container-use` (MCP) |

Native `/sandbox` runs Bash *on the host toolchain*, so it can't make "no Python" true; `container-use`
targets standing dev envs, not throwaway from-nothing verification. **That empty middle row — clean-base
install/bootstrap testing — is the gap this skill fills.**

Beyond filling the gap, it's honest about its limits: capable agents already reach for a container when the
question is posed neutrally — a cross-lineage control did so unaided. So this skill isn't "teach agents to
containerize." It earns its keep on three narrower points:

- **Anti-shenanigan guardrail.** Under a leading *"find/arrange a machine without X"* framing, the destructive
  temptation is to SSH a **shared** host and uninstall/strip the tool to manufacture the condition —
  irreversible risk to someone else's hardware for a throwaway test. `docker run` an image that *never had X*
  is the cheap, explicit stop.
- **Reliable trigger.** A registered description fires on the situation, rather than relying on each agent to
  reason its way there.
- **Field caveats a fresh agent skips** — architecture (arm64 vs x86), musl vs glibc, `0.0.0.0`+`-p`
  reachability, multi-homed interface / QR pointing at an unreachable address, unique-name teardown,
  `/dev/tty` vs stdin piping.

## Install

Copy `SKILL.md` into your agent's skills directory, e.g. `~/.claude/skills/docker-clean-room/SKILL.md`.

## Status

A **brick** (抛磚引玉 — throw a brick to attract jade): clear and usable, but not yet fully pressure-tested.
See the note at the bottom of `SKILL.md` for exactly what's measured and what isn't. Issues / refinements welcome.

## License

[CC0-1.0](./LICENSE) — public-domain dedication.
