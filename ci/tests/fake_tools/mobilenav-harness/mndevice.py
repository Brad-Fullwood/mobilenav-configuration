"""Stand-in for mndevice.py in check.py tests. Prints the fixture named by FAKE_ASSERT and logs the call to FAKE_LOG."""
import os, pathlib, sys

FIX = pathlib.Path(__file__).resolve().parents[2] / "fixtures"
argv = sys.argv[1:]
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write("mndevice " + " ".join(argv) + "\n")
text = (FIX / os.environ.get("FAKE_ASSERT", "assert_ok.txt")).read_text()
print(text, end="")
sys.exit(1 if " 0 failed" not in text else 0)
