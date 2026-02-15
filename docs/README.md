# zemit

Opinionated release automation tool for Zig projects.

**zemit** aims to be the GoReleaser equivalent for the Zig ecosystem:
a single tool to build, package, and publish multi-target releases
in a predictable and reproducible way.

---

## What is zemit?

zemit is a CLI tool that automates the **release pipeline** of Zig projects.

Its goal is to handle, in one place:

- multi-target compilation
- deterministic artifact naming
- packaging (zip / tar.gz)
- checksum generation
- release metadata
- publishing to GitHub, GitLab, and Codeberg

All while remaining explicit, scriptable, and transparent.

---

## Project status

**Experimental — v0.1.x**

zemit is under active development.

The core build pipeline is implemented and usable.
Higher-level release features (checksums, compression, provider APIs)
are planned and will be introduced incrementally.

Breaking changes may occur during the 0.x series.

---

## Requirements

- Zig **0.13.0** (recommended)

---

## Quick start

Inside a Zig project generated via `zig init`:

```bash
zemit release
````

Verbose mode (full Zig output):

```bash
zemit -v release
```

---

## Current capabilities (v0.1.0)

* Validate Zig project structure
* Build binaries for multiple targets
* Deterministic artifact naming
* Clean and predictable output
* TTY-aware UX (colors, spinners)

Artifacts are written to:

```text
.zemit/dist/<target>/
```

---

## Example output

```text
[1/12] x86_64-linux-gnu ok (0.50s)
[2/12] x86_64-linux-musl ok (0.50s)
[3/12] aarch64-linux-gnu ok (3.00s)
...
✓ Compilation completed! Binaries in: .zemit/dist (31.02s)
```

---

## Output layout

```text
.zemit/dist/x86_64-linux-musl/yourbin
.zemit/dist/x86_64-windows-gnu/yourbin.exe
.zemit/dist/aarch64-macos/yourbin
```

Binary names include version and target when applicable.

---

## Supported targets (v0.1.0)

* x86_64-linux-gnu
* x86_64-linux-musl
* aarch64-linux-gnu
* aarch64-linux-musl
* arm-linux-gnueabihf
* arm-linux-musleabihf
* riscv64-linux-gnu
* riscv64-linux-musl
* x86_64-windows-gnu
* x86_64-windows-msvc
* x86_64-macos
* aarch64-macos

> Note:
> Some targets may require host support or SDKs
> (e.g. macOS SDK, MSVC toolchain).
>
> If a target fails, rerun:
>
> ```bash
> zemit -v release
> ```

---

## Roadmap (high level)

Planned features include:

* Artifact compression (zip / tar.gz)
* Checksum generation (sha256)
* GitHub / GitLab / Codeberg providers
* Automatic release upload to tags
* Config file (`zemit.toml`)
* Selective target builds

See `ROADMAP.md` for details.

---

## Installation

### Manual

```bash
zig build -Doptimize=ReleaseSmall -Dstrip=true
```

Binary path:

```text
zig-out/bin/zemit
```

Copy it to a directory in your `PATH`.

---

### install.sh

```bash
chmod +x install.sh
./install.sh
```

---

## Philosophy

> Do one thing.
> Do it well.
> Make it explicit.

zemit follows a pragmatic Unix-style philosophy:

* explicit stages
* predictable behavior
* minimal magic
* composable output

---

## Repository

Canonical repository:
- https://codeberg.org/lucaas-d3v/zemit

Mirrors:
- https://github.com/lucaas-d3v/zemit
- https://gitlab.com/lucaas-d3v/zemit

---

## Contributing

Contributions, issues, and design discussions are welcome.

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening
issues or pull requests.

---

## License

[`MIT`](LICENSE)