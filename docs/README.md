# zemit

Opinionated release automation tool for Zig projects.

**zemit** is a release automation CLI inspired by GoReleaser,
but designed specifically for Zig’s build system and philosophy.

Its goal is to provide a single, explicit, and reproducible way
to build, package, and publish multi-target releases for Zig projects.

---

## What is zemit?

zemit automates the **release pipeline** of Zig projects, handling:

- multi-target compilation
- deterministic artifact naming
- packaging (zip / tar.gz) - in the future
- checksum generation - in the future
- release metadata - in the future
- publishing to Codeberg, GitHub and GitLab - in the future

All while remaining explicit, scriptable, and predictable.

No hidden magic. No implicit side effects.

---

## Project status

**Experimental — v0.x**

zemit is under active development.

The core build pipeline is usable and stable enough for real projects,
but higher-level release features (compression, checksums, provider APIs)
are still evolving.

Breaking changes may occur until v1.0.

---

## Requirements

- Zig **0.13.0** (recommended)

---

## Quick start

Inside a Zig project generated with `zig init`:

```bash
zemit release
````

Verbose mode (full Zig output):

```bash
zemit -v release
```

Artifacts are written by default in:

```text
zemit/dist/
```

---

## Current capabilities

* Optional `zemit.toml` configuration file
* Configurable optimization mode
* Custom Zig build arguments
* Multi-target builds
* Deterministic artifact naming
* Clean, predictable output
* TTY-aware UX (colors, spinners)

Some configuration sections are currently placeholders and
will be implemented incrementally.

---

## Example configuration

```toml
[build]
optimize = "ReleaseSmall"
zig_args = ["-Dstrip=true"]

[release]
targets = [
  "x86_64-linux-gnu",
  "x86_64-linux-musl",
  "x86_64-windows-gnu",
]
```

See [`config.md`](config.md) for the full configuration reference.

---

## Example output

```text
[1/3] x86_64-linux-gnu ok (0.48s)
[2/3] x86_64-linux-musl ok (0.51s)
[3/3] x86_64-windows-gnu ok (1.12s)
✓ Compilation completed! Binaries in .zemit/dist (2.11s)
```

---

## Output layout

```text
zemit/dist/x86_64-linux-musl/yourbin
zemit/dist/x86_64-windows-gnu/yourbin.exe
zemit/dist/aarch64-macos/yourbin
```

Binary names include version and target when applicable.

---

## Supported targets

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
> If a target fails, rerun with:
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
* Selective target builds


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

* [https://codeberg.org/lucaas-d3v/zemit](https://codeberg.org/lucaas-d3v/zemit)

Mirrors:

* [https://github.com/lucaas-d3v/zemit](https://github.com/lucaas-d3v/zemit)
* [https://gitlab.com/lucaas-d3v/zemit](https://gitlab.com/lucaas-d3v/zemit)

---

## Contributing

Contributions, issues, and design discussions are welcome.

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening
issues or pull requests.

---

## License

[`MIT`](LICENSE)
