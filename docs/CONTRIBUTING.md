# Contributing to zemit

Thanks for your interest in contributing to **zemit**.

zemit aims to be a complete, opinionated release tool for Zig projects,
similar in spirit to GoReleaser — but designed with Zig’s ecosystem,
build system, and philosophy in mind.

This document explains how to contribute in a way that keeps zemit
powerful, maintainable, and coherent as it grows.

---

## Project vision

zemit’s long-term goal is to provide a **full release pipeline** for Zig projects:

- multi-target builds
- deterministic artifact naming
- compression (zip / tar.gz)
- checksums
- release metadata
- integration with:
  - GitHub
  - GitLab
  - Codeberg
- automated publishing to tags

At the same time, zemit aims to remain:

- explicit
- predictable
- scriptable
- transparent in behavior

zemit prefers **clear stages** over hidden magic.

---

## Project status

zemit is currently in **v0.1.x**.

This means:
- the core architecture is being established
- new features are expected
- interfaces may evolve
- design discussions are welcome

However, architectural consistency matters more than speed.

---

## How zemit is structured conceptually

zemit is designed around **explicit phases**:

1. **Discovery**
   - project validation
   - version and tag resolution
2. **Build**
   - multi-target compilation
3. **Artifact**
   - naming
   - compression
   - checksums
4. **Release**
   - provider APIs (GitHub/GitLab/Codeberg)
   - upload
   - metadata
5. **Report**
   - clear output
   - reproducible logs

Contributions should fit clearly into one of these phases.

---

## Ways to contribute

### 1. Bug reports

Please include:

- zemit version
- Zig version
- host OS and architecture
- exact command used
- full output (use `-v` when possible)

Minimal reproduction steps are strongly encouraged.

---

### 2. Feature proposals

Before implementing a feature, **open an issue**.

Describe:
- the problem being solved
- which phase it belongs to
- why it should live in zemit instead of an external tool
- expected UX and flags

Large features without prior discussion may be rejected.

---

### 3. Code contributions

Pull requests are welcome if they respect the project structure
and design principles described below.

---

## Branching model

zemit uses a simple and explicit branching model designed to scale from
solo development to multiple contributors.

### Permanent branches

- `main`
  - Always stable
  - Must always represent a releasable state
  - No direct development

- `dev`
  - Integration branch
  - Features and fixes are merged here first
  - May be temporarily unstable

### Working branches

All work must be done in short-lived branches created from `dev`.

Naming convention:

- `feat/<short-description>`
- `fix/<short-description>`
- `docs/<short-description>`
- `refactor/<short-description>`
- `chore/<short-description>`

Examples:

- `feat/init-command`
- `fix/toml-parser`
- `refactor/cli-layout`

---
## Design principles

### Explicit over implicit

zemit should never surprise the user.

- No hidden network calls
- No implicit uploads
- No automatic side effects without clear flags

If something modifies remote state, it must be obvious.

---

### Modularity over monoliths

Features should be implemented as **well-defined modules**.

Examples:
- checksum generation
- compression formats
- provider APIs

Avoid tightly coupled code across unrelated stages.

---

### Provider neutrality

GitHub, GitLab, and Codeberg integrations should:

- share a common interface
- avoid provider-specific assumptions
- be easily extensible to future providers

---

### Error handling

- Errors must be explicit and actionable
- Network errors must show provider and operation
- Partial failures must be reported clearly

Never swallow errors silently.

---

### CLI and UX

Output must be:

- readable by humans
- stable for scripts
- quiet by default
- detailed with `-v`

Rules:
- colors only when in a TTY
- animations only when in a TTY
- no emojis
- consistent formatting across commands

---

## Code style

- Zig 0.13.0
- Avoid unnecessary abstractions
- Prefer small, testable functions
- Avoid clever tricks
- No hidden allocations in hot paths

If a change adds complexity, it must add proportional value.

---

## Commit guidelines

- One logical change per commit
- Clear, descriptive messages

Examples:

```

build: add artifact compression stage
release: add GitHub provider upload support
checksum: generate sha256 files for artifacts
cli: add --skip-upload flag

```

---

## Pull request checklist

Before opening a PR:

- [ ] Builds with Zig 0.13.0
- [ ] Feature fits one clear pipeline stage
- [ ] UX is documented (README or help output)
- [ ] Errors are handled explicitly
- [ ] No unintended side effects
- [ ] No hardcoded credentials or tokens

---

## Design discussions

Design discussions are welcome and encouraged.

When proposing changes:
- explain trade-offs
- consider future providers
- avoid provider lock-in
- prefer boring, correct designs

zemit values long-term maintainability over short-term wins.

---

## Code of conduct

Be respectful and constructive.

Strong technical disagreement is welcome.
Personal attacks, gatekeeping, or dismissive behavior are not.

---

## Final note

zemit is ambitious by design.

It aims to solve a real gap in the Zig ecosystem,
and that requires discipline as the project grows.

Contributions that respect this vision are very welcome.
