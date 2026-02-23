# zemit configuration reference

This document describes the `zemit.toml` configuration file.

## Current support

As of the current release (v0.2.x), zemit supports:

* `[build]`: `optimize`, `zig_args`
* `[release]`: `targets`
* `[dist]`: `dir`, `layout`, `name_template`

Other fields that may appear in example snippets (such as `[checksums]`) are **reserved for future versions** and may be **ignored** today.

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

### `layout` (supported)

Controls how release artifacts are organized inside the distribution directory.

Allowed values:

* `by-target` (default)
* `flat`

Default:

```toml
layout = "by-target"
```

#### `by-target`

Artifacts are grouped by target triple.

Example layout:

```
dist/
x86_64-linux-gnu/
zemit-0.2.2-x86_64-linux-gnu
x86_64-windows-gnu/
zemit-0.2.2-x86_64-windows-gnu.exe
```

This layout preserves target separation and is recommended for multi-platform releases.

#### `flat`

All artifacts are written directly into the distribution directory.

Example layout:

```
dist/
zemit-0.2.2-x86_64-linux-gnu
zemit-0.2.2-x86_64-windows-gnu.exe
```

This layout is useful for simple packaging, scripting, or when target separation is not required.

---
### `name_template` (supported)

Controls the output filename for release artifacts.

Default:

```toml
name_template = "{bin}-{version}-{target}{ext}"
```

#### Available variables:

- {bin}: project or binary name

- {version}: version string (from build.zig)

- {target}: current target triple

- {ext}: platform-specific extension

> (e.g. .exe on Windows, empty on other platforms)

#### Example:

```toml
[dist]
layout = "flat"
name_template = "{bin}-{version}-{target}{ext}"
```

#### Produces (example):

- zemit-0.2.2-x86_64-linux-gnu
- zemit-0.2.2-x86_64-windows-gnu.exe

#### Template validation

The template is validated at runtime.

- Unknown variables cause an error
- Invalid or unmatched braces cause an error

Example error:

```txt
ERROR: Unknown variable 'exta' at position '24'

    {bin}-{version}-{target}{exta}
                            ^^^^^^
```

This helps catch mistakes early and avoids silently producing incorrect artifact names.

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
