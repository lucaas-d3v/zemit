## Installation

### Manual
Compile
```bash
zig build -Doptimize=ReleaseSmall
```

The binary will be generated in:
```text
zig-out/bin/zemit
```

You can copy it to a directory in your `PATH`.

### Via `install.sh`

Give permission
```bash
sudo chmod +x install.sh
```

Run
```bash
./install.sh
```

---

## Philosophy

> Do one thing.
> Do it well.
> Exit.

zemit follows the Unix tools philosophy:

* simple
* predictable
* easy to compose