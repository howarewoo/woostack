#!/usr/bin/env bash
# provision-omp-session-name.sh — install woostack's project-scoped OMP session naming extension and settings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export WOOSTACK_OMP_SESSION_NAME_TEMPLATE="$(cd "$SCRIPT_DIR/../templates" && pwd -P)/omp-session-name.ts"

exec /usr/bin/env python3 - "$@" <<'PY'
import json, os, stat, subprocess, sys, tempfile

MANAGED_EXT = ".omp/extensions/woostack-session-name.ts"
MANAGED_RULES = ("settings.json", "extensions/woostack-session-name.ts")


def fail(msg):
    print(f"provision-omp-session-name.sh: {msg}", file=sys.stderr)
    raise SystemExit(1)


def check_node(path, is_dir=False):
    if not os.path.lexists(path):
        return "missing", None
    try:
        st = os.lstat(path)
    except OSError as e:
        return "malformed", f"inaccessible: {e}"
    if is_dir:
        if not stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode) or os.path.realpath(path) != path:
            return "malformed", "must be a canonical real directory without symlinks"
    elif stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
        return "malformed", "must be a regular file without symlinks"
    return "ok", st


def ensure_dir(parent, name):
    path = os.path.join(parent, name)
    if not os.path.lexists(path):
        os.mkdir(path, 0o755)
    status, _ = check_node(path, is_dir=True)
    if status != "ok":
        fail(f"{path} must be a real directory without symlinks")
    return path


def read_regular(path):
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    fd = os.open(path, flags)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError("not a regular file")
        chunks = []
        while True:
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks).decode("utf-8")
    finally:
        os.close(fd)


def write_atomic(path, content):
    fd, tmp = tempfile.mkstemp(prefix=f".{os.path.basename(path)}.", dir=os.path.dirname(path), text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as dst:
            dst.write(content)
            dst.flush()
            os.fsync(dst.fileno())
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def is_git_tracked(repo_root, rel_path):
    try:
        return subprocess.run(["git", "-C", repo_root, "ls-files", "--error-unmatch", rel_path], capture_output=True).returncode == 0
    except OSError:
        return False


def get_template():
    tpl = os.environ.get("WOOSTACK_OMP_SESSION_NAME_TEMPLATE")
    if not tpl:
        fail("WOOSTACK_OMP_SESSION_NAME_TEMPLATE is missing")
    try:
        return read_regular(tpl)
    except Exception as e:
        fail(f"cannot read template {tpl}: {e}")


def rule_counts(raw):
    return {r: sum(line == r for line in raw.splitlines()) for r in MANAGED_RULES}


def normalized_ignore(raw):
    kept = [s for s in raw.splitlines(keepends=True) if s.rstrip("\r\n") not in MANAGED_RULES]
    prefix = "".join(kept)
    if prefix and not prefix.endswith(("\n", "\r")):
        prefix += "\n"
    return f"{prefix}{''.join(r + chr(10) for r in MANAGED_RULES)}"


def merge_settings(parsed):
    data = dict(parsed)
    exts = data.get("extensions")
    data["extensions"] = [MANAGED_EXT] if exts is None else [x for x in exts if x != MANAGED_EXT] + [MANAGED_EXT]
    return data


args = sys.argv[1:]
check = bool(args and args[0] == "--check")
if check:
    args = args[1:]
if len(args) > 1:
    print("usage: provision-omp-session-name.sh [--check] [repository]", file=sys.stderr)
    raise SystemExit(2)
root = os.path.abspath(args[0] if args else ".")
if os.path.realpath(root) != root or check_node(root, is_dir=True)[0] != "ok":
    fail("repository must be a canonical real directory")

omp_dir, ext_dir = os.path.join(root, ".omp"), os.path.join(root, ".omp", "extensions")
ext_path, settings_path, ignore_path = os.path.join(ext_dir, "woostack-session-name.ts"), os.path.join(omp_dir, "settings.json"), os.path.join(omp_dir, ".gitignore")
template_body = get_template()

if check:
    for d in (omp_dir, ext_dir):
        status, err = check_node(d, is_dir=True)
        if status == "malformed":
            print(f"malformed\t{d}\t{err}")
            raise SystemExit(0)
    # Ext check
    status, _ = check_node(ext_path)
    if status == "missing":
        print(f"missing\t{ext_path}\tmanaged OMP session-naming extension is missing")
    elif status == "malformed":
        print(f"malformed\t{ext_path}\tmanaged OMP session-naming extension is a symlink or unsafe non-regular file")
    else:
        try:
            if read_regular(ext_path) != template_body:
                print(f"drifted\t{ext_path}\tmanaged OMP session-naming extension differs from the shipped template")
        except (OSError, UnicodeError):
            print(f"malformed\t{ext_path}\tmanaged OMP session-naming extension is unreadable or unsafe")
    # Settings check
    if is_git_tracked(root, ".omp/settings.json"):
        print(f"malformed\t{settings_path}\tproject OMP settings file is tracked by git; local settings must remain untracked")
    else:
        status, _ = check_node(settings_path)
        if status == "missing":
            print(f"missing\t{settings_path}\tproject OMP settings file is missing managed extension entry")
        elif status == "malformed":
            print(f"malformed\t{settings_path}\tproject OMP settings file is a symlink or unsafe non-regular file")
        else:
            try:
                parsed = json.loads(read_regular(settings_path))
                if not isinstance(parsed, dict) or not isinstance(parsed.get("extensions", []), list):
                    print(f"malformed\t{settings_path}\tproject OMP settings file must be a JSON object with a valid extensions list")
                else:
                    cnt = sum(x == MANAGED_EXT for x in parsed.get("extensions", []))
                    if cnt == 0:
                        print(f"drifted\t{settings_path}\tproject OMP settings file is missing managed extension entry")
                    elif cnt > 1:
                        print(f"drifted\t{settings_path}\tproject OMP settings file must contain exactly one managed extension entry")
            except (json.JSONDecodeError, UnicodeError, OSError):
                print(f"malformed\t{settings_path}\tproject OMP settings file is unreadable, malformed, or unsafe")
    # Ignore check
    status, _ = check_node(ignore_path)
    if status == "missing":
        print(f"missing\t{ignore_path}\tproject OMP ignore file is missing")
    elif status == "malformed":
        print(f"malformed\t{ignore_path}\tproject OMP ignore file is a symlink or unsafe non-regular file")
    else:
        try:
            if not all(c == 1 for c in rule_counts(read_regular(ignore_path)).values()):
                print(f"drifted\t{ignore_path}\tproject OMP ignore file must contain standalone rules for settings.json and extensions/woostack-session-name.ts")
        except (OSError, UnicodeError):
            print(f"malformed\t{ignore_path}\tproject OMP ignore file is unreadable or unsafe")
    raise SystemExit(0)

for d in (omp_dir, ext_dir):
    status, err = check_node(d, is_dir=True)
    if status == "malformed":
        fail(f"{d} {err}")
if is_git_tracked(root, ".omp/settings.json"):
    fail("project OMP settings file is tracked by git; local settings must remain untracked")
for f in (ext_path, settings_path, ignore_path):
    status, err = check_node(f)
    if status == "malformed":
        fail(f"{f} {err}")

settings_parsed, ignore_raw = {}, ""
if os.path.lexists(settings_path):
    try:
        settings_parsed = json.loads(read_regular(settings_path))
        if not isinstance(settings_parsed, dict) or not isinstance(settings_parsed.get("extensions", []), list) or any(not isinstance(x, str) for x in settings_parsed.get("extensions", [])):
            fail(f"{settings_path} must be a JSON object with a valid list of extension paths")
    except Exception as e:
        fail(f"{settings_path} is malformed or unreadable: {e}")
if os.path.lexists(ext_path):
    try:
        read_regular(ext_path)
    except Exception as e:
        fail(f"{ext_path} is unsafe or unreadable: {e}")
if os.path.lexists(ignore_path):
    try:
        ignore_raw = read_regular(ignore_path)
    except Exception as e:
        fail(f"{ignore_path} is unsafe or unreadable: {e}")

ensure_dir(root, ".omp")
ensure_dir(omp_dir, "extensions")

# Write atomic updates
if os.path.lexists(ext_path) and read_regular(ext_path) == template_body:
    print(f"preserved\t{ext_path}")
else:
    write_atomic(ext_path, template_body)
    print(f"installed\t{ext_path}")

wanted_settings = json.dumps(merge_settings(settings_parsed), indent=2) + "\n"
if os.path.lexists(settings_path) and sum(x == MANAGED_EXT for x in settings_parsed.get("extensions", [])) == 1 and read_regular(settings_path) == wanted_settings:
    print(f"preserved\t{settings_path}")
else:
    write_atomic(settings_path, wanted_settings)
    print(f"installed\t{settings_path}")

if os.path.lexists(ignore_path) and all(c == 1 for c in rule_counts(ignore_raw).values()):
    print(f"preserved\t{ignore_path}")
else:
    write_atomic(ignore_path, normalized_ignore(ignore_raw))
    print(f"installed\t{ignore_path}")
PY
