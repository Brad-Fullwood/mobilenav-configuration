"""Stand-in for mnconfig.py in check.py tests."""
import os, pathlib, sys

FIX = pathlib.Path(__file__).resolve().parents[2] / "fixtures"
argv = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write("mnconfig " + " ".join(argv) + "\n")
cmd = next(a for a in argv if a in ("raw", "preview", "apply", "doctor"))
if cmd == "raw":
    print(os.environ.get("FAKE_PROVIDERS", '[{"providerId": "EXAMPLE", "name": "MobileNAV Configuration Example", "state": "Applied"}]'))
else:
    text = (FIX / os.environ.get("FAKE_" + cmd.upper(), {"preview": "preview_nochange.txt", "apply": "apply_ok.txt", "doctor": "doctor_clean.txt"}[cmd])).read_text()
    print(text, end="")
