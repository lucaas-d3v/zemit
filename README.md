# zemit

Opinionated multi-target releaser for Zig CLIs.

`zemit release` builds your Zig project for multiple targets and places the correctly named binaries in `.zemit/dist/`.

## Requirements
- Zig 0.13.0 (recommended)

## Quick start
Inside a Zig project (generated via `zig init`):

```bash
zemit release
````

Verbose mode:

```bash
zemit -v release
```

## Output

Artifacts are written to:

```text
.zemit/dist/<target>/<bin>
```

Example:

```text
.zemit/dist/x86_64-linux-musl/yourbin
.zemit/dist/x86_64-windows-gnu/yourbin.exe
.zemit/dist/aarch64-macos/yourbin
```

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

> Note: Some targets may require host support or SDKs (e.g. macOS, MSVC).
> If a target fails, rerun with `zemit -v release` to see the full Zig build output.

## Installation

### Manual

```bash
zig build -Doptimize=ReleaseSmall -Dstrip=true
```

Binary:

```text
zig-out/bin/zemit
```

Copy it to a directory in your `PATH`.

### install.sh

```bash
chmod +x install.sh
./install.sh
```

## Philosophy

> Do one thing. Do it well. Exit.

zemit follows the Unix tools philosophy:

* simple
* predictable
* easy to compose

## Non-goals (v0.1.0)

* GitHub/GitLab/Codeberg release upload
* checksums
* compression (zip/tar.gz)
* changelog generation
