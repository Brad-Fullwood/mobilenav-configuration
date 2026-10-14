"""Stand-in for bcbd.py in check.py tests. Prints the fixture named by FAKE_<COMMAND> and logs the call to FAKE_LOG."""
import os, pathlib, sys

FIX = pathlib.Path(__file__).resolve().parents[2] / "fixtures"
argv = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write("bcbd " + " ".join(argv) + "\n")
cmd = next(a for a in argv if a in ("build", "upload", "login"))
if cmd == "login":
    print("saved application login 'ci'")
elif cmd == "build":
    out = pathlib.Path(argv[argv.index("--out-dir") + 1])
    out.mkdir(parents=True, exist_ok=True)
    text = (FIX / os.environ.get("FAKE_BUILD", "build_ok.txt")).read_text()
    app = out / "fake.app"
    if text.startswith("# OK"):
        app.write_bytes(b"x")
        text = text.replace(text.split("app=")[1].split(" diagnostics=")[0], str(app))
    print(text, end="")
    sys.exit(0 if "diagnostics=0" in text and "FAILED" not in text else 1)
elif cmd == "upload":
    text = (FIX / os.environ.get("FAKE_UPLOAD", "upload_ok.txt")).read_text()
    print(text, end="")
    sys.exit(0 if "Completed" in text else 1)
