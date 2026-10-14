#!/usr/bin/env python3
"""Configuration CI for a MobileNAV Configuration app.

One script for the steps a pull request must pass, so the GitHub and Azure pipeline files stay thin.
It calls bcbd.py and mnconfig.py from the tools repo (BC_TOOLS or --tools) and reads their text output.

  setup     install the AL compiler from the Visual Studio Marketplace when none is installed
  build     download symbols, compile with the full cop set, fail on any diagnostic
  deploy    upload the built app(s) to the sandbox (skipped with --no-deploy)
  apply     apply the providers the app declares (skipped with --no-apply)
  device    sign in as the harness device and assert the declared controls are there and wired
            (mndevice.py assert). Runs only with --device
  preview   mnconfig preview for every provider the app declares, fail on any error line
  doctor    mnconfig doctor, fail on a finding at Warning or above
  all       setup, build, deploy, preview, apply, device (with --device), doctor, then a table; exit code 1 if any step failed

Settings come from options or environment: BC_TENANT, BC_ENVIRONMENT, BC_COMPANY (optional), and for
a sign-in without a person BC_CLIENT_ID and BC_CLIENT_SECRET (a Microsoft Entra application). Without
BC_CLIENT_ID the tools use their own sign-in (the AL token cache) and the app's .vscode/launch.json.
"""
import argparse
import gzip
import io
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

LOGIN_NAME = "ci"
SEVERITIES = ["Blocker", "Warning", "Info"]
MARKETPLACE_URL = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-dynamics-smb/vsextensions/al/{version}/vspackage"
ALCOPS_VERSION = "1.3.1"   # pinned: a new cop release can add rules and fail a pull request that changed no code
ALCOPS_URL = "https://api.nuget.org/v3-flatcontainer/alcops.analyzers/{v}/alcops.analyzers.{v}.nupkg"
PROVIDER_INTERFACE = "BJF MN Config Provider"


class Fail(Exception):
    """A step failed. The message is the one line shown in the table."""


# ---------------------------------------------------------------------------
# Parsers for the text the tools print. Pure functions, covered by tests/test_check.py.
# ---------------------------------------------------------------------------

def last_json(text):
    """The JSON object on the last line of a tool's output that starts with `{`. None when there is no such line or
    it does not parse. The tools print it last under --json."""
    lines = [l.strip() for l in text.splitlines() if l.strip().startswith("{")]
    if not lines:
        return None
    try:
        return json.loads(lines[-1])
    except ValueError:
        return None


def parse_build(text):
    """Read `bcbd.py build --json` output.

    Returns a dict with ok (bool), app (path or None), diagnostics (int), errors (compile error lines),
    crashes (analyzer crash count), list_file (path of the full diagnostic list or None), missing_analyzers
    (list) and summary (bool, False when the tool printed no JSON line).
    """
    result = {"ok": False, "app": None, "diagnostics": 0, "errors": [], "crashes": 0, "list_file": None, "summary": False, "missing_analyzers": []}
    j = last_json(text)
    if j is not None:
        result.update(ok=bool(j.get("ok")), app=j.get("app"), diagnostics=j.get("diagnostics", 0), errors=j.get("errors", []),
                      crashes=j.get("crashes", 0), list_file=j.get("list_file"), missing_analyzers=j.get("missing_analyzers", []), summary=True)
    return result


def parse_upload(text):
    """Read `bcbd.py upload --json` output. Returns the statuses seen, in order, whether the deployment completed, and
    the installed entries. Without a JSON line: no statuses and not completed."""
    j = last_json(text) or {}
    return {"statuses": j.get("statuses", []), "completed": bool(j.get("completed")), "installed": j.get("installed", [])}


def parse_preview(text):
    """Read `mnconfig.py preview --json` output.

    Returns errors (the messages the apply would stop with), not_found (bool), fields and records (change counts)
    and nothing_to_change (bool: no changes and no errors). Without a JSON line the errors and the not-found line
    are read from the text, so a stop still fails the step.
    """
    j = last_json(text)
    if j is None:
        return {"errors": [l.split("The apply would stop with:", 1)[1].strip() for l in text.splitlines() if "The apply would stop with:" in l],
                "not_found": bool(re.search(r"^provider \S+ not found", text, flags=re.M)),
                "fields": 0, "records": 0, "nothing_to_change": False}
    return {"errors": j.get("errors", []), "not_found": False, "fields": j.get("fields", 0), "records": j.get("records", 0),
            "nothing_to_change": j.get("fields", 0) == 0 and not j.get("errors")}


def parse_assert(text):
    """Read `mndevice.py assert --json` output. Returns checks and failed (None when the tool printed no JSON line)
    and failures, one "page | control | check | expected | actual" string per failed check."""
    j = last_json(text)
    if j is None:
        return {"checks": None, "failed": None, "failures": []}
    rows = [" | ".join(str(f.get(k) or "") for k in ("page", "control", "check", "expected", "actual")) for f in j.get("failures", [])]
    return {"checks": j.get("checks"), "failed": j.get("failed"), "failures": rows}


def parse_findings(text):
    """Read `mnconfig.py doctor --json` output. Returns a list of dicts (severity, entry, check, message, fixable),
    empty when the tool printed no JSON line."""
    j = last_json(text) or {}
    return [{"severity": f.get("severity"), "entry": f.get("entryNo"), "check": f.get("checkType"),
             "message": f.get("message") or "", "fixable": bool(f.get("fixable"))} for f in j.get("findings") or []]


def findings_at_or_above(findings, severity):
    """Findings whose severity is `severity` or more serious. Blocker is the most serious."""
    limit = SEVERITIES.index(severity)
    return [f for f in findings if f["severity"] in SEVERITIES and SEVERITIES.index(f["severity"]) <= limit]


def parse_apply(text):
    """Read `mnconfig.py apply --json` output. Returns the state of each provider ('Applied', 'Outdated', ...).
    A provider without a state is left out."""
    j = last_json(text) or {}
    return [p["state"] for p in j.get("providers", []) if p.get("state")]


def parse_provider_ids(source):
    """Provider ids declared in AL source: the GetId result of every codeunit implementing the provider interface.

    Handles `exit(this.IdTok)` with a Label and `exit('ID')` with a literal. Returns (ids, unresolved codeunit names).
    """
    ids, unresolved = [], []
    pattern = re.compile(r'codeunit\s+\d+\s+"?([^"\r\n]+?)"?\s+implements\s+[^\r\n{]*"%s"' % re.escape(PROVIDER_INTERFACE))
    for m in pattern.finditer(source):
        body = source[m.end():]
        nxt = re.search(r"^\s*codeunit\s+\d+\s", body, flags=re.M)
        body = body[:nxt.start()] if nxt else body
        g = re.search(r"procedure\s+GetId\s*\(\s*\)[^\r\n]*\s+begin\s+exit\(([^;]*?)\)\s*;", body, flags=re.S | re.I)
        value = None
        if g:
            expr = g.group(1).strip()
            lit = re.fullmatch(r"'((?:[^']|'')*)'", expr)
            if lit:
                value = lit.group(1).replace("''", "'")
            else:
                label = re.fullmatch(r"(?:this\.)?(\w+)", expr)
                if label:
                    lm = re.search(r"\b%s\s*:\s*Label\s+'((?:[^']|'')*)'" % re.escape(label.group(1)), body)
                    value = lm.group(1).replace("''", "'") if lm else None
        (ids if value else unresolved).append(value or m.group(1))
    return ids, unresolved


# ---------------------------------------------------------------------------
# Context and helpers
# ---------------------------------------------------------------------------

def strip_json_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    return re.sub(r",(\s*[\]}])", r"\1", text)


class App:
    """An AL app folder: manifest, where its build lands."""

    def __init__(self, folder, out_root, stamp=None):
        self.folder = pathlib.Path(folder).resolve()
        if not (self.folder / "app.json").exists():
            raise Fail(f"no app.json in {self.folder}: pass --app with the AL app folder")
        self.manifest = json.loads(strip_json_comments((self.folder / "app.json").read_text(encoding="utf-8-sig")))
        self.stamp = stamp
        self.out_dir = pathlib.Path(out_root) / re.sub(r"[^\w.-]+", "_", self.manifest["name"])

    @property
    def name(self):
        return self.manifest["name"]

    @property
    def version(self):
        """The version that is built: the manifest's, with the fourth part replaced when a stamp is given."""
        v = self.manifest["version"]
        return ".".join(v.split(".")[:3] + [str(self.stamp)]) if self.stamp is not None else v

    @property
    def app_file(self):
        return self.out_dir / f"{self.manifest['publisher']}_{self.name}_{self.version}.app"


class Ctx:
    def __init__(self, args):
        self.args = args
        self.tools = find_tools(args.tools or os.environ.get("BC_TOOLS"))
        self.out_root = pathlib.Path(args.out_dir or os.environ.get("CHECK_OUT_DIR") or pathlib.Path(tempfile.gettempdir()) / "configuration-ci")
        stamp = args.stamp_revision if args.stamp_revision is not None else None
        if args.cmd == "setup":
            self.main, self.withs = None, []
        else:
            self.main = App(args.app, self.out_root, stamp)
            self.withs = [App(p, self.out_root, stamp) for p in args.with_app]
        self.tenant = args.tenant or os.environ.get("BC_TENANT")
        self.environment = args.env or os.environ.get("BC_ENVIRONMENT")
        self.company = args.company or os.environ.get("BC_COMPANY")
        self.env = dict(os.environ)
        self.results = []
        self.source_provider_ids = None

    @property
    def apps(self):
        """Every app of the run in dependency order: the --with apps first, the main app last."""
        return self.withs + [self.main]

    def tool_args(self, app):
        a = ["--project", str(app.folder)]
        if self.tenant:
            a += ["--tenant", self.tenant]
        if self.environment:
            a += ["--env", self.environment]
        if self.company:
            a += ["--company", self.company]
        return a

    def bcbd(self, app, *cmd):
        return run([sys.executable, str(self.tools[0])] + self.tool_args(app) + list(cmd), self.env)

    def mnconfig(self, *cmd):
        return run([sys.executable, str(self.tools[1])] + self.tool_args(self.main) + list(cmd), self.env)

    def mndevice(self, *cmd):
        if not self.tools[2]:
            raise Fail("mndevice.py not found under the tools repo (mobilenav-harness folder): update the checkout")
        return run([sys.executable, str(self.tools[2])] + self.tool_args(self.main) + list(cmd), self.env)


def find_tools(path):
    """Locate bcbd.py, mnconfig.py and mndevice.py under the tools repo path (the repo root or its business-central folder).

    Returns (bcbd.py, mnconfig.py, mndevice.py). mndevice.py is None when the checkout has no harness: only the device step needs it."""
    if not path:
        raise Fail("set BC_TOOLS or pass --tools: the path of the tools repo checkout")
    root = pathlib.Path(path).expanduser()
    for base in (root, root / "business-central"):
        bcbd = base / "bc-build-deploy" / "bcbd.py"
        mn = base / "mobilenav-config" / "mnconfig.py"
        if bcbd.exists() and mn.exists():
            device = base / "mobilenav-harness" / "mndevice.py"
            return bcbd, mn, device if device.exists() else None
    raise Fail(f"bcbd.py and mnconfig.py not found under {root} (looked in bc-build-deploy and mobilenav-config)")


def run(cmd, env, timeout=3600):
    """Run a command, echo its output as it arrives and return (exit code, full output)."""
    lines = []
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env, errors="replace")
    started = time.time()
    try:
        for line in proc.stdout:
            print(line, end="", flush=True)
            lines.append(line)
            if time.time() - started > timeout:
                proc.kill()
                lines.append(f"timed out after {timeout} s\n")
                break
    finally:
        proc.wait()
    return proc.returncode, "".join(lines)


def last_line(text, default="no output"):
    """The line that says what went wrong: the first one naming a failure, else the last non-empty line."""
    rows = [l.strip() for l in text.splitlines() if l.strip()]
    for l in rows:
        if re.search(r"\bfailed\b|\bnot found\b|\bError\b|sign-in", l):
            return re.sub(r"[:\s]*\{$", "", l[:300])
    return rows[-1][:300] if rows else default


def step(ctx, name, func, *args):
    """Run one step function, record (name, result, seconds, detail). A Fail or an unexpected error is a FAIL row."""
    started = time.time()
    print(f"\n=== {name} ===", flush=True)
    try:
        detail = func(ctx, *args)
        result = "ok"
        if isinstance(detail, tuple):
            result, detail = detail
    except Fail as e:
        result, detail = "FAIL", str(e)
    except Exception as e:  # a bug here must not look like a pass
        result, detail = "FAIL", f"{type(e).__name__}: {e}"
    ctx.results.append((name, result, round(time.time() - started), detail or ""))
    return result != "FAIL"


def skip(ctx, name, why):
    ctx.results.append((name, "skipped", 0, why))


def print_table(results):
    rows = [("step", "result", "sec", "detail")] + [(n, r, str(s), d) for n, r, s, d in results]
    w = [max(len(r[i]) for r in rows) for i in range(3)]
    print("\n" + "-" * 78)
    for r in rows:
        print(f"{r[0].ljust(w[0])}  {r[1].ljust(w[1])}  {r[2].rjust(w[2])}  {r[3]}")
    print("-" * 78)


# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

def al_extension_dirs():
    home = pathlib.Path.home()
    return [home / ".vscode" / "extensions", home / ".cursor" / "extensions", home / ".vscode-server" / "extensions"]


def installed_compiler():
    for base in al_extension_dirs():
        found = sorted(base.glob("ms-dynamics-smb.al-*/bin/alc.dll"))
        if found:
            return found[-1]
    return None


def unwrap_download(data):
    """The marketplace may answer with a gzip stream around the vsix (a zip)."""
    return gzip.decompress(data) if data[:2] == b"\x1f\x8b" else data


def extract_extension(vsix_bytes, target_base):
    """Unpack the `extension/` folder of a vsix to <target_base>/ms-dynamics-smb.al-<version>. Returns that folder."""
    z = zipfile.ZipFile(io.BytesIO(vsix_bytes))
    version = json.loads(z.read("extension/package.json"))["version"]
    dest = pathlib.Path(target_base) / f"ms-dynamics-smb.al-{version}"
    root = dest.resolve()
    for info in z.infolist():
        if not info.filename.startswith("extension/") or info.is_dir():
            continue
        out = (dest / info.filename[len("extension/"):]).resolve()
        if root not in out.parents:
            raise Fail(f"vsix entry outside the extension folder: {info.filename}")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(z.read(info))
    return dest


def check_dotnet(alc):
    """alc needs the runtime named in its runtimeconfig. Fail with the missing version rather than a stack trace."""
    cfg = json.loads((alc.parent / "alc.runtimeconfig.json").read_text())
    want = cfg["runtimeOptions"]["framework"]["version"].split(".")[0]
    try:
        out = subprocess.run(["dotnet", "--list-runtimes"], capture_output=True, text=True).stdout
    except FileNotFoundError:
        raise Fail("dotnet is not on PATH") from None
    if not re.search(r"Microsoft\.NETCore\.App %s\." % want, out):
        raise Fail(f"the AL compiler needs .NET {want}, installed runtimes: " + ", ".join(re.findall(r"NETCore\.App (\S+)", out)))


def install_alcops(alc):
    """Put the ALCops analyzers next to alc.dll, where bcbd.py looks for them. The marketplace extension does not ship them."""
    if (alc.parent / "ALCops.LinterCop.dll").exists():
        return "ALCops present"
    version = os.environ.get("BC_ALCOPS_VERSION") or ALCOPS_VERSION
    tfm = json.loads((alc.parent / "alc.runtimeconfig.json").read_text())["runtimeOptions"]["tfm"]
    url = ALCOPS_URL.format(v=version)
    print(f"downloading {url}", flush=True)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "configuration-ci"}), timeout=600) as r:
            z = zipfile.ZipFile(io.BytesIO(r.read()))
    except urllib.error.URLError as e:
        raise Fail(f"ALCops {version} could not be downloaded: {e}") from None
    names = [n for n in z.namelist() if n.startswith(f"lib/{tfm}/") and n.endswith(".dll")]
    if not names:
        raise Fail(f"ALCops {version} has no lib/{tfm} folder")
    for n in names:
        (alc.parent / pathlib.Path(n).name).write_bytes(z.read(n))
    return f"ALCops {version} installed"


def do_setup(ctx):
    alc = installed_compiler()
    note = "compiler present"
    if not alc:
        version = os.environ.get("BC_AL_VERSION") or "latest"
        url = MARKETPLACE_URL.format(version=version)
        print(f"downloading {url}", flush=True)
        data = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "configuration-ci"}), timeout=600) as r:
                    data = unwrap_download(r.read())
                break
            except urllib.error.URLError as e:
                print(f"download attempt {attempt + 1} failed: {e}", flush=True)
                time.sleep(5)
        if data is None:
            raise Fail("the AL extension could not be downloaded from the marketplace")
        dest = extract_extension(data, al_extension_dirs()[0])
        alc = dest / "bin" / "alc.dll"
        if not alc.exists():
            raise Fail(f"{alc} missing after unpacking the vsix")
        note = f"installed {dest.name}"
    check_dotnet(alc)
    return f"{note}, {install_alcops(alc)}"


def do_login(ctx):
    """Save an Entra application login when BC_CLIENT_ID is set, then make the tools use it through BCBD_LOGIN."""
    client = os.environ.get("BC_CLIENT_ID")
    if not client:
        return "no BC_CLIENT_ID: the tools use their own sign-in"
    if not os.environ.get("BC_CLIENT_SECRET"):
        raise Fail("BC_CLIENT_ID is set but BC_CLIENT_SECRET is not")
    if not ctx.tenant:
        raise Fail("BC_TENANT is not set")
    rc, out = ctx.bcbd(ctx.main, "login", "--as", LOGIN_NAME, "--app", "--client-id", client, "--secret-env", "BC_CLIENT_SECRET")
    if rc != 0:
        raise Fail(last_line(out))
    ctx.env["BCBD_LOGIN"] = LOGIN_NAME
    return f"application {client[:8]}... signed in"


def symbol_requests(app, withs):
    """What to download for an app: (publisher, name, version) of the Microsoft apps and its dependencies.

    Apps built in the same run (`withs`) are skipped, the build supplies them. The Microsoft base apps
    (Base Application, System Application, Business Foundation) are added by the caller from the Application
    package's own dependency list.
    """
    local_ids = {w.manifest["id"] for w in withs}
    wanted = []
    m = app.manifest
    if m.get("application"):
        wanted.append(("Microsoft", "Application", m["application"]))
    if m.get("platform"):
        wanted.append(("Microsoft", "System", m["platform"]))
    for d in m.get("dependencies", []):
        if d.get("id") in local_ids:
            continue
        wanted.append((d.get("publisher"), d.get("name"), d.get("version") or d.get("minVersion") or "0.0.0.0"))
    return wanted


def package_dependencies(app_bytes):
    """Dependencies named in the NavxManifest.xml of a .app (the zip starts at the first PK header)."""
    z = zipfile.ZipFile(io.BytesIO(app_bytes[app_bytes.find(b"PK\x03\x04"):]))
    xml = z.read("NavxManifest.xml").decode("utf-8", "replace")
    return [(m.group(2), m.group(1), m.group(3)) for m in
            re.finditer(r'<Dependency [^>]*?Name="([^"]*)" Publisher="([^"]*)" MinVersion="([^"]*)"', xml)]


def download_symbol(bcbd, ctx, publisher, name, version):
    """Fetch one symbol package from the environment's developer endpoint. Returns (filename, bytes) or None on 404."""
    q = urllib.parse.urlencode({"publisher": publisher, "appName": name, "versionText": version, "tenant": "default"})
    url = bcbd.base({"tenant": ctx.tenant, "env": ctx.environment}) + f"/dev/packages?{q}"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"Authorization": "Bearer " + bcbd.get_token(ctx.tenant)})
            with urllib.request.urlopen(req, timeout=600) as r:
                disposition = r.headers.get("Content-Disposition", "")
                fm = re.search(r"filename\*=UTF-8''([^;]+)", disposition) or re.search(r'filename="?([^";]+)"?', disposition)
                fname = urllib.parse.unquote(fm.group(1)) if fm else f"{publisher}_{name}_{version}.app"
                return pathlib.Path(fname).name, r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if attempt == 2:
                raise Fail(f"symbols for {name} failed: HTTP {e.code}") from None
        except urllib.error.URLError:
            if attempt == 2:
                raise
        time.sleep(5)
    return None


def load_bcbd(ctx):
    """Import bcbd.py for its token handling (the same code the tools use for every other call)."""
    sys.path.insert(0, str(ctx.tools[0].parent))
    import bcbd
    os.environ.update({k: v for k, v in ctx.env.items() if k == "BCBD_LOGIN"})
    return bcbd


def do_symbols(ctx, app):
    if not ctx.tenant or not ctx.environment:
        cfg = ctx.main.folder / ".vscode" / "launch.json"
        if not cfg.exists():
            raise Fail("BC_TENANT and BC_ENVIRONMENT are needed to download symbols")
        launch = json.loads(strip_json_comments(cfg.read_text()))
        conf = next((c for c in launch.get("configurations", []) if c.get("type") == "al"), {})
        ctx.tenant = ctx.tenant or conf.get("tenant")
        ctx.environment = ctx.environment or conf.get("environmentName")
    bcbd = load_bcbd(ctx)
    packages = app.folder / ".alpackages"
    packages.mkdir(exist_ok=True)
    wanted = symbol_requests(app, ctx.withs)
    got, missing, seen = [], [], set()
    while wanted:
        publisher, name, version = wanted.pop(0)
        if (publisher, name) in seen:
            continue
        seen.add((publisher, name))
        have = sorted(packages.glob(f"{publisher}_{name}_*.app"))
        if have and not ctx.args.refresh_symbols:
            data = have[-1].read_bytes()
        else:
            res = download_symbol(bcbd, ctx, publisher, name, version)
            if res is None:
                missing.append(f"{publisher} {name} {version}")
                continue
            fname, data = res
            for old in have:
                old.unlink()
            (packages / fname).write_bytes(data)
            got.append(name)
        if (publisher, name) == ("Microsoft", "Application"):
            wanted += [(p, n, "0.0.0.0") for p, n, _ in package_dependencies(data)]
    if missing:
        raise Fail("no symbols in the environment for: " + ", ".join(missing))
    return f"{app.name}: {len(got)} downloaded" + (f" ({', '.join(got)})" if got else ", all present")


def stamped(apps):
    """Context manager that writes the stamped version into each app.json and puts the originals back."""
    class _Stamp:
        def __enter__(self_inner):
            self_inner.saved = []
            for a in apps:
                if a.stamp is None:
                    continue
                path = a.folder / "app.json"
                raw = path.read_bytes()
                self_inner.saved.append((path, raw))
                text = raw.decode("utf-8-sig")
                path.write_text(re.sub(r'("version"\s*:\s*")[^"]+(")', lambda m: m.group(1) + a.version + m.group(2), text, count=1), encoding="utf-8")
            return self_inner

        def __exit__(self_inner, *exc):
            for path, raw in self_inner.saved:
                path.write_bytes(raw)
    return _Stamp()


def build_one(ctx, app):
    app.out_dir.mkdir(parents=True, exist_ok=True)
    rc, out = ctx.bcbd(app, "build", "--out-dir", str(app.out_dir), "--all", "--json")
    r = parse_build(out)
    problems = []
    if r["errors"]:
        problems.append(f"{len(r['errors'])} compile errors, first: {r['errors'][0][:200]}")
    if r["crashes"]:
        problems.append(f"{r['crashes']} analyzer crashes")
    if r["missing_analyzers"]:
        problems.append("analyzers missing, so the cop set is partial: " + ", ".join(r["missing_analyzers"]))
    if r["diagnostics"]:
        first = ""
        if r["list_file"] and pathlib.Path(r["list_file"]).exists():
            lines = pathlib.Path(r["list_file"]).read_text().splitlines()
            first = f", first: {lines[0][:200]}" if lines else ""
        problems.append(f"{r['diagnostics']} diagnostics{first}")
    if not r["summary"]:
        problems.append("no summary line from bcbd.py build: " + last_line(out))
    elif rc != 0 and not problems:
        problems.append(f"bcbd.py build exited {rc}")
    if problems:
        raise Fail(f"{app.name}: " + "; ".join(problems))
    return pathlib.Path(r["app"])


def do_build(ctx):
    do_setup(ctx)
    notes = []
    with stamped(ctx.apps):
        for app in ctx.apps:
            if not ctx.args.no_symbols:
                notes.append(do_symbols(ctx, app))
            built = build_one(ctx, app)
            app.built = built
            for other in ctx.apps:
                if other is not app and any(d.get("id") == app.manifest["id"] for d in other.manifest.get("dependencies", [])):
                    pk = other.folder / ".alpackages"
                    pk.mkdir(exist_ok=True)
                    for old in pk.glob(f"{app.manifest['publisher']}_{app.name}_*.app"):
                        old.unlink()
                    shutil.copy2(built, pk / built.name)
            notes.append(f"{app.name} {app.version}: 0 diagnostics")
    return "; ".join(n for n in notes if "downloaded" not in n and "present" not in n) or "ok"


def built_file(app):
    path = getattr(app, "built", None) or app.app_file
    if not pathlib.Path(path).exists():
        raise Fail(f"{path} not found: run the build step first")
    return pathlib.Path(path)


def do_deploy(ctx):
    done = []
    for app in ctx.apps:
        f = built_file(app)
        rc, out = ctx.bcbd(app, "upload", str(f), "--json")
        r = parse_upload(out)
        if rc != 0 or not r["completed"]:
            raise Fail(f"{app.name}: " + (last_line(out) if rc != 0 else f"deployment status {r['statuses'][-1] if r['statuses'] else 'unknown'}"))
        done.append(f"{app.name} {app.version}")
    return "uploaded " + ", ".join(done)


def provider_ids(ctx):
    """The provider ids to check: --provider, else read from the app's source once per run."""
    if ctx.args.provider:
        return list(ctx.args.provider)
    if ctx.source_provider_ids is not None:
        return list(ctx.source_provider_ids)
    ids, unresolved = [], []
    for path in sorted(ctx.main.folder.rglob("*.al")):
        i, u = parse_provider_ids(path.read_text(encoding="utf-8-sig", errors="replace"))
        ids += i
        unresolved += u
    if unresolved:
        raise Fail("cannot read the id of provider codeunit " + ", ".join(unresolved) + ": pass --provider ID")
    ctx.source_provider_ids = ids
    return list(ids)


def with_providers(ctx, func):
    """Run func(ctx, ids) for the app's providers. Skipped when the app declares none."""
    ids = provider_ids(ctx)
    if not ids:
        return ("skipped", "the app declares no provider")
    return func(ctx, ids)


def registered_providers(ctx):
    rc, out = ctx.mnconfig("raw", "configProviders", "--select", "providerId,name,state")
    if rc != 0:
        raise Fail("reading the providers failed: " + last_line(out))
    try:
        return {p["providerId"].upper() for p in json.loads(out[out.index("["):])}
    except ValueError:
        raise Fail("unreadable provider list: " + last_line(out)) from None


def do_preview(ctx, ids):
    known = registered_providers(ctx)
    absent = [i for i in ids if i.upper() not in known]
    if absent:
        raise Fail("the environment does not list provider " + ", ".join(absent) + (" (use deploy first)" if ctx.args.no_deploy else ""))
    notes, errors = [], []
    for pid in ids:
        rc, out = ctx.mnconfig("preview", pid, "--json")
        r = parse_preview(out)
        if r["errors"]:
            errors += [f"{pid}: {e[:200]}" for e in r["errors"]]
        elif rc != 0 or r["not_found"]:
            errors.append(f"{pid}: {last_line(out)}")
        else:
            notes.append(f"{pid}: " + ("no changes" if r["nothing_to_change"] else f"{r['fields']} field changes in {r['records']} records"))
    if errors:
        raise Fail("; ".join(errors))
    return "; ".join(notes)


def do_apply(ctx, ids):
    states = []
    for pid in ids:
        rc, out = ctx.mnconfig("apply", pid, "--json")
        states_here = parse_apply(out)
        if rc != 0 or not states_here or states_here[-1] != "Applied":
            raise Fail(f"{pid}: " + (last_line(out) if rc != 0 else f"state after apply: {states_here[-1] if states_here else 'unknown'}"))
        states.append(f"{pid} Applied")
    return ", ".join(states)


def do_device(ctx, ids):
    """Capture as the harness device and assert each provider's declaration. The device sees what the apply step wrote."""
    notes, errors = [], []
    for pid in ids:
        cmd = ["assert", "--provider", pid, "--app", str(ctx.main.folder), "--stored", "--json"]
        if ctx.args.device_id:
            cmd += ["--device-id", ctx.args.device_id]
        if ctx.args.device_profile:
            cmd += ["--profile", ctx.args.device_profile]
        rc, out = ctx.mndevice(*cmd)
        r = parse_assert(out)
        if r["failed"] is None:
            errors.append(f"{pid}: {last_line(out)}")
        elif r["failed"] or rc != 0:
            errors.append(f"{pid}: {r['failed']} of {r['checks']} device checks failed, first: {(r['failures'] or [last_line(out)])[0][:200]}")
        else:
            notes.append(f"{pid}: {r['checks']} device checks passed")
    if errors:
        raise Fail("; ".join(errors))
    return "; ".join(notes)


def do_doctor(ctx):
    rc, out = ctx.mnconfig("doctor", "--json")
    findings = parse_findings(out)
    if rc != 0 and not findings:
        raise Fail(last_line(out))
    bad = findings_at_or_above(findings, ctx.args.fail_on)
    if bad:
        first = bad[0]
        raise Fail(f"{len(bad)} findings at {ctx.args.fail_on} or above, first: [{first['severity']}] {first['check']}: {first['message'][:200]}")
    counts = {s: sum(1 for f in findings if f["severity"] == s) for s in SEVERITIES}
    return "no findings" if not findings else ", ".join(f"{n} {s}" for s, n in counts.items() if n)


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

def make_parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--tools", help="tools repo checkout (default: BC_TOOLS)")
    common.add_argument("--app", default=".", help="the AL app folder to check (default: current folder)")
    common.add_argument("--with", dest="with_app", action="append", default=[], metavar="FOLDER",
                        help="an app of this repo that --app depends on: built first, its .app used as a symbol, uploaded first (repeatable)")
    common.add_argument("--tenant", help="default: BC_TENANT, else the app's .vscode/launch.json")
    common.add_argument("--env", help="environment name. Default: BC_ENVIRONMENT, else launch.json")
    common.add_argument("--company", help="company name. Default: BC_COMPANY, else the environment's only company")
    common.add_argument("--out-dir", help="where builds land (default: <temp>/configuration-ci)")
    common.add_argument("--provider", action="append", help="provider id to preview and apply (default: read from the app's source)")
    common.add_argument("--stamp-revision", type=int, help="replace the fourth part of every built version, so each CI run is a higher version than the last (app.json is restored afterwards)")
    common.add_argument("--no-symbols", action="store_true", help="do not download symbols: .alpackages is already filled")
    common.add_argument("--refresh-symbols", action="store_true", help="download symbols again even when .alpackages has the package")
    common.add_argument("--no-deploy", action="store_true", help="skip the upload: preview and doctor read what is installed")
    common.add_argument("--no-apply", action="store_true", help="skip the apply between preview and doctor")
    common.add_argument("--device", action="store_true", help="also run the device step: sign in as the harness device and assert the declared controls (writes a login log row and uses a device licence, sandbox only)")
    common.add_argument("--device-id", help="device id of the harness device (default: the harness's BJF-HARNESS-01)")
    common.add_argument("--device-profile", help="profile code of the CI user: its Field rows override the declared Visible and Editable")
    common.add_argument("--fail-on", default="Warning", choices=SEVERITIES, help="doctor severity that fails the run (default Warning)")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("setup", "build", "deploy", "apply", "preview", "device", "doctor", "all"):
        sub.add_parser(name, parents=[common])
    return ap


def run_steps(ctx, cmd):
    a = ctx.args
    if cmd == "setup":
        step(ctx, "setup", do_setup)
        return
    if not step(ctx, "login", do_login):
        return
    if cmd in ("build", "all"):
        if not step(ctx, "build", do_build):
            for s in ("deploy", "apply", "preview", "device", "doctor") if cmd == "all" else ():
                skip(ctx, s, "build failed")
            return
    if cmd in ("deploy", "all"):
        if a.no_deploy:
            skip(ctx, "deploy", "--no-deploy")
        elif not step(ctx, "deploy", do_deploy):
            for s in ("apply", "preview", "device", "doctor") if cmd == "all" else ():
                skip(ctx, s, "deploy failed")
            return
    preview_ok = True
    if cmd in ("preview", "all"):
        preview_ok = step(ctx, "preview", with_providers, do_preview)
    apply_ok = preview_ok
    if cmd in ("apply", "all"):
        if a.no_apply:
            skip(ctx, "apply", "--no-apply")
        elif not preview_ok:
            skip(ctx, "apply", "preview failed")
        else:
            apply_ok = step(ctx, "apply", with_providers, do_apply)
    if cmd in ("device", "all"):
        if not a.device:
            skip(ctx, "device", "pass --device to run")
        elif not apply_ok:
            skip(ctx, "device", "apply failed" if cmd == "all" else "preview failed")
        else:
            step(ctx, "device", with_providers, do_device)
    if cmd in ("doctor", "all"):
        step(ctx, "doctor", do_doctor)


def main(argv=None):
    args = make_parser().parse_args(argv)
    try:
        ctx = Ctx(args)
    except Fail as e:
        print(f"check.py: {e}", file=sys.stderr)
        return 1
    run_steps(ctx, args.cmd)
    print_table(ctx.results)
    return 1 if any(r[1] == "FAIL" for r in ctx.results) else 0


if __name__ == "__main__":
    sys.exit(main())
