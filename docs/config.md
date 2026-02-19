# zemit configuration reference

This document describes the `zemit.toml` configuration file.

## Current support

As of the current release (v0.2.x), zemit supports:

* `[build]`: `optimize`, `zig_args`
* `[release]`: `targets`
* `[dist]`: `dir`

Everything else that may appear in example snippets (such as `layout`, `name_template`, or `[checksums]`) is **reserved for future versions** and may be **ignored** today.

`zemit.toml` is optional. If the file is missing or fields are omitted, zemit falls back to its built-in defaults.

---

## File location

By default, zemit looks for a `zemit.toml` file in the project root.

If the file is not found, zemit will proceed using default values.

---

## `[build]` section

Controls how Zig builds are executed.

```toml
[build]
optimize = "ReleaseSmall"
zig_args = ["-Dstrip=true"]
```

### `optimize`

Controls the Zig optimization mode.

Allowed values:

* `Debug`
* `ReleaseSafe`
* `ReleaseFast`
* `ReleaseSmall`

Default:

```toml
optimize = "ReleaseSmall"
```

This value is passed directly to `zig build`.

---

### `zig_args`

Additional arguments passed verbatim to the Zig build system.

Example:

```toml
zig_args = ["-Dstrip=true", "-Dcpu=baseline"]
```

Notes:

* Arguments are not validated by zemit
* Invalid arguments will cause the build to fail
* Order is preserved

---

## `[release]` section

Controls which targets are built during a release.

```toml
[release]
targets = [
  "x86_64-linux-gnu",
  "x86_64-linux-musl",
  "x86_64-windows-gnu",
]
```

### `targets`

List of Zig targets to build.

Each entry must be a valid Zig target triple.

If omitted, zemit will use a default target set.

Notes:

* Host toolchains or SDKs may be required
* Failed targets do not stop the entire release by default
* You can run `zig targets` to see all targets list supported by zig

---

## `[dist]` section

Controls where artifacts are written.

```toml
[dist]
dir = "zig-out/dist"
```

### `dir` (supported)

Base output directory for all artifacts.

Example:

```toml
dir = "zig-out/dist"
```

---

### `layout` (reserved / not implemented yet)

This field is reserved for future output layouts.

If present today, it may be ignored.

---

### `name_template` (reserved / not implemented yet)

This field is reserved for future artifact naming templates.

If present today, it may be ignored.

---

## `[checksums]` section (reserved / not implemented yet)

This section is not implemented in the current release.

If present today, it may be ignored.

Example (reserved):

```toml
[checksums]
enabled = true
algorithms = ["sha256"]
file = "checksums.txt"
```

---

## Omission behavior

* `zemit.toml` is optional.
* Omitted supported fields fall back to the tool’s built-in defaults.
* Reserved fields may be ignored until they are implemented.

---

## Design notes

* zemit prefers explicit configuration over hidden auto-detection.
* Reserved fields exist to stabilize the config surface early.
* Configuration may evolve during the 0.x series.
