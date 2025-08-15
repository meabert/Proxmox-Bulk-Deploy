#!/usr/bin/env python3
import json, os, shutil, subprocess, sys

MARGIN_BYTES = 2 * 1024 * 1024 * 1024  # 2 GiB

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def which(cmd, fallback=None):
    p = shutil.which(cmd)
    return p if p else fallback

def run(cmd):
    return subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True).stdout

def get_node():
    return run([which("hostname", "/bin/hostname")]).strip()

def get_storages(node):
    pvesh = which("pvesh", "/usr/bin/pvesh")
    out = run([pvesh, "get", f"/nodes/{node}/storage", "--output-format", "json"])
    return json.loads(out)

def qemu_virtual_size(path):
    if not (path and os.path.exists(path)):
        return 0
    qemu_img = which("qemu-img", "/usr/bin/qemu-img")
    if not qemu_img:
        return 0
    out = run([qemu_img, "info", "--output", "json", path])
    j = json.loads(out)
    return int(j.get("virtual-size", 0))

def build_candidates(node, required_bytes):
    cands = []
    for s in get_storages(node):
        if not s.get("enabled", True):
            continue
        if not s.get("active", False):
            continue
        if s.get("type") not in ("zfspool", "lvmthin", "lvm"):
            continue
        content = s.get("content", "")
        if "images" not in [c.strip() for c in content.split(",")]:
            continue
        avail = int(s.get("avail", 0))
        ok = (required_bytes == 0) or (avail >= required_bytes)
        label = f'{s.get("storage")} ({s.get("type")}, free {avail/1024/1024/1024:.1f} GiB)' + ("" if ok else " [INSUFFICIENT SPACE]")
        cands.append((avail, label, s.get("storage"), ok))
    cands.sort(key=lambda x: x[0], reverse=True)
    return cands

def tty_input(prompt, default=None):
    # Prefer /dev/tty to avoid stdin redirection issues
    try:
        with open("/dev/tty", "r") as tin, open("/dev/tty", "w", buffering=1) as tout:
            tout.write(prompt)
            s = tin.readline()
            if not s:
                return default
            s = s.strip()
            return s if s else default
    except Exception:
        try:
            s = input(prompt)
            s = s.strip()
            return s if s else default
        except EOFError:
            return default

def main():
    # Env override: if STORAGE_TARGET is set, just use it
    pre = os.environ.get("STORAGE_TARGET", "").strip()
    if pre:
        print(pre)
        return

    image = sys.argv[1] if len(sys.argv) > 1 else ""
    node = get_node()
    required = qemu_virtual_size(image) + (MARGIN_BYTES if image else 0)

    cands = build_candidates(node, required)
    if not cands:
        eprint("No eligible storages found.")
        sys.exit(1)

    # Default is first storage that meets space requirement, else the largest
    default_idx = next((i for i, c in enumerate(cands) if c[3]), 0)

    auto = os.environ.get("AUTO_PICK", "").lower() in ("1", "true")
    has_tty = sys.stdin.isatty()
    # If no TTY or AUTO_PICK requested, auto-select
    if auto or not has_tty:
        print(cands[default_idx][2])
        return

    # Add cancel sentinel at end
    cancel_label = "Cancel / Exit without selecting"
    cands.append((0, cancel_label, None, True))  # avail=0, storage=None

    eprint("Available storage targets:")
    for i, (_, label, _, _) in enumerate(cands, 1):
        eprint(f"{i:2d}) {label}")
    eprint()
    eprint(f"Default: {default_idx+1}  (Ctrl+C also cancels)")

    while True:
        choice = tty_input(
            f"\n💾 Make your selection [1-{len(cands)}] "
            f"(default {default_idx+1}): ",
            default=str(default_idx+1)
        )
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(cands):
                _, _, name, ok = cands[idx]
                if name is None:
                    eprint("Selection cancelled by user.")
                    sys.exit(0)
                if not ok and required > 0:
                    yn = tty_input("Selected storage may be low on space. Continue anyway? [y/N]: ", default="n").lower()
                    if yn not in ("y", "yes"):
                        continue
                print(name)
                return
        except ValueError:
            pass
        eprint("Please enter a valid number.")

if __name__ == "__main__":
    main()
