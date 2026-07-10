# docker-clean-room

An agent **skill** (Claude Code / Agent Skills format) for proving something works *from a clean base* —
an `install.sh` on a fresh machine, a tool self-bootstrapping its own runtime ("does it work with **no
Python** installed?"), or a lockfile/dependency change resolving from nothing. Spin a **disposable Docker
container** as the clean-room, `docker exec` + bash-pipe into it, toss it when done — instead of testing on
the host (whose toolchain leaks in) or stripping a real shared machine to fake the condition.

## What you get

- **A reliable trigger.** A registered skill fires on the situation ("test this from a fresh machine", "does
  it work with no X installed", a lockfile/pin PR) — so the clean-room approach shows up when it's needed,
  instead of relying on an agent to reason its way there each time.
- **The field caveats a fresh agent skips** — the load-bearing content. Architecture (arm64 vs x86), musl vs
  glibc, `0.0.0.0`+`-p` reachability, multi-homed interface / QR pointing at an unreachable address,
  root-vs-user masking install bugs, unpinned-base drift, `/dev/tty` vs stdin piping, and "not a security
  boundary / `docker.sock` = host-root". These are the traps that turn a green clean-room test into a false pass.
- **An honest proof boundary.** A container makes the *userland* clean, not the whole machine — it still shares
  the host kernel, drivers, networking, and service manager. The skill says exactly what it *proves* (userland
  from nothing ✓) and what it *doesn't* (kernel / GPU / boot / networking / root-vs-user / reproducibility ✗),
  so "from nothing" never overstates.
- **An anti-shenanigan guardrail.** Under a leading *"find/arrange a machine without X"* framing, the destructive
  temptation is to SSH a **shared** host and uninstall/strip the tool to manufacture the condition — irreversible
  risk to someone else's hardware for a throwaway test. `docker run` an image that *never had X* is the cheap,
  explicit stop. Low-probability, but kept on consequences-dominate grounds.

## Try it

[`clean-room.sh`](./clean-room.sh) *is* the recipe, as a runnable self-test — no faith required:

```bash
./clean-room.sh   # Python-free debian → uv self-bootstraps CPython from nothing → PASS → tossed
```

Verified green on arm64 / Apple Silicon. It self-disarms (removes the box on Ctrl-C or any failure).

## Where it fits

Three distinct needs get conflated — existing tools cover the *outer* two:

| Need | Tool |
|---|---|
| Isolate execution for *safety* | native `/sandbox` (OS-level, built into Claude Code) |
| **Prove it works from a clean base** — no host tools leak in | **this skill** |
| Parallel isolated *dev environments* | Dagger `container-use` (MCP) |

Plain `docker run` can of course do clean-base verification too — this skill isn't a new *capability*, it's the
one that **packages it as a triggerable recipe with the field caveats attached**. Native `/sandbox` runs Bash
*on the host toolchain*, so it can't make "no Python" true; `container-use` targets standing dev envs, not
throwaway from-nothing verification.

## Install

Copy `SKILL.md` into your agent's skills directory, e.g. `~/.claude/skills/docker-clean-room/SKILL.md`
(and `clean-room.sh` alongside it if you want the runnable self-test).

<details>
<summary>Status &amp; honest limits (it's a brick, 抛磚引玉)</summary>

A **brick** — clear and usable, but not yet fully pressure-tested. Measured baseline, so the value isn't oversold:

- Capable agents already reach for a container when the question is posed **neutrally** — a clean cross-lineage
  control (Codex/GPT-5, without this skill) did so unaided, and 5/5 reps under *leading* framing refused the
  destructive uninstall-on-shared-host move. So this is **not** "teach agents to containerize" — the container
  *choice* isn't where capable agents fail.
- What it genuinely earns is the four points above: **trigger · field caveats · proof boundary · anti-shenanigan
  guardrail**. Of those, the **field caveats are the one thing every fresh/foreign agent misses** — treat those
  as the core.
- Measured on arm64 / Apple Silicon, Docker Desktop; x86 unverified. See the note at the bottom of `SKILL.md`
  for exactly what's measured and what isn't. Issues / refinements welcome.

</details>

## License

[CC0-1.0](./LICENSE) — public-domain dedication.
