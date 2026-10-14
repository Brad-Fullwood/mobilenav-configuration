"""Tests for ci/check.py: the parsers on recorded or documented tool output, and whole runs against fake tools.

    python3 -m unittest discover -s ci/tests        # from the repository root
"""
import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
FIX = HERE / "fixtures"
FAKE_TOOLS = HERE / "fake_tools"
sys.path.insert(0, str(HERE.parent))
import check  # noqa: E402


def fixture(name):
    return (FIX / name).read_text()


class ParseBuild(unittest.TestCase):
    def test_clean(self):
        r = check.parse_build(fixture("build_ok.txt"))
        self.assertTrue(r["ok"])
        self.assertEqual(r["diagnostics"], 0)
        self.assertTrue(r["app"].endswith("Brad Fullwood_MobileNAV Configuration Example_2.0.0.0.app"))

    def test_diagnostics(self):
        r = check.parse_build(fixture("build_diagnostics.txt"))
        self.assertEqual(r["diagnostics"], 7)
        self.assertTrue(r["summary"])

    def test_compile_errors_crashes_and_missing_analyzers(self):
        r = check.parse_build(fixture("build_compile_error.txt"))
        self.assertFalse(r["ok"])
        self.assertIsNone(r["app"])
        self.assertEqual(len(r["errors"]), 2)
        self.assertEqual(r["crashes"], 2)
        self.assertEqual(r["missing_analyzers"], ["ALCops.LinterCop.dll", "ALCops.Common.dll"])

    def test_no_summary(self):
        self.assertFalse(check.parse_build("Traceback ...")["summary"])


class ParseUpload(unittest.TestCase):
    def test_completed(self):
        r = check.parse_upload(fixture("upload_ok.txt"))
        self.assertTrue(r["completed"])
        self.assertEqual(r["statuses"], ["InProgress", "InProgress", "Completed"])

    def test_failed(self):
        r = check.parse_upload(fixture("upload_failed.txt"))
        self.assertFalse(r["completed"])
        self.assertEqual(r["statuses"][-1], "Failed")


class ParsePreview(unittest.TestCase):
    def test_changes(self):
        r = check.parse_preview(fixture("preview_changes.txt"))
        self.assertEqual((r["fields"], r["records"], r["errors"]), (3, 2, []))

    def test_error_line(self):
        r = check.parse_preview(fixture("preview_error.txt"))
        self.assertEqual(len(r["errors"]), 1)
        self.assertIn("Button Scan on MNItem", r["errors"][0])

    def test_nothing_to_change(self):
        self.assertTrue(check.parse_preview(fixture("preview_nochange.txt"))["nothing_to_change"])

    def test_not_found(self):
        self.assertTrue(check.parse_preview("provider X not found; run: providers")["not_found"])

    def test_stop_without_json_still_an_error(self):
        r = check.parse_preview("The apply would stop with: Button Scan on MNItem names function Nope.\n")
        self.assertEqual(r["errors"], ["Button Scan on MNItem names function Nope."])


class ParseFindings(unittest.TestCase):
    def test_none(self):
        self.assertEqual(check.parse_findings(fixture("doctor_clean.txt")), [])

    def test_lines(self):
        f = check.parse_findings(fixture("doctor_findings.txt"))
        self.assertEqual([x["severity"] for x in f], ["Info", "Warning", "Blocker"])
        self.assertTrue(f[1]["fixable"])
        self.assertEqual(f[1]["entry"], 2)
        self.assertNotIn("fixable", f[1]["message"])

    def test_threshold(self):
        f = check.parse_findings(fixture("doctor_findings.txt"))
        self.assertEqual([x["entry"] for x in check.findings_at_or_above(f, "Warning")], [2, 3])
        self.assertEqual([x["entry"] for x in check.findings_at_or_above(f, "Blocker")], [3])
        self.assertEqual(len(check.findings_at_or_above(f, "Info")), 3)
        self.assertEqual(check.findings_at_or_above(f[:1], "Warning"), [])


class ParseAssert(unittest.TestCase):
    def test_passed(self):
        r = check.parse_assert(fixture("assert_ok.txt"))
        self.assertEqual((r["checks"], r["failed"], r["failures"]), (76, 0, []))

    def test_failures(self):
        r = check.parse_assert(fixture("assert_failed.txt"))
        self.assertEqual((r["checks"], r["failed"]), (77, 2))
        self.assertEqual(len(r["failures"]), 2)
        self.assertTrue(r["failures"][0].startswith("MNExampleStockCount | LotNo | visible"))

    def test_no_summary(self):
        self.assertIsNone(check.parse_assert("Traceback ...")["failed"])


class ParseApplyAndProviders(unittest.TestCase):
    def test_apply_state(self):
        self.assertEqual(check.parse_apply(fixture("apply_ok.txt")), ["Applied"])
        self.assertEqual(check.parse_apply('{"providers": [{"providerId": "EXAMPLE", "state": "Outdated", "appliedAt": null}]}'), ["Outdated"])
        self.assertEqual(check.parse_apply("  -> Applied appliedAt=2026-10-14T01:20:00Z"), [])

    def test_provider_ids(self):
        ids, unresolved = check.parse_provider_ids(fixture("Provider.Codeunit.al"))
        self.assertEqual(ids, ["EXAMPLE", "LIT-1"])
        self.assertEqual(unresolved, [])

    def test_unresolved_id(self):
        src = 'codeunit 1 "P" implements "BJF MN Config Provider"\n{\n procedure GetId(): Code[50]\n begin\n exit(Compute());\n end;\n}\n'
        ids, unresolved = check.parse_provider_ids(src)
        self.assertEqual((ids, unresolved), ([], ["P"]))

    def test_source_read_once_per_run(self):
        with tempfile.TemporaryDirectory() as d:
            src = pathlib.Path(d) / "Provider.Codeunit.al"
            src.write_text(fixture("Provider.Codeunit.al"))
            ctx = type("Ctx", (), {})()
            ctx.args = type("Args", (), {"provider": None})()
            ctx.main = type("App", (), {"folder": pathlib.Path(d)})()
            ctx.source_provider_ids = None
            self.assertEqual(check.provider_ids(ctx), ["EXAMPLE", "LIT-1"])
            src.unlink()
            self.assertEqual(check.provider_ids(ctx), ["EXAMPLE", "LIT-1"])

    def test_real_example_provider(self):
        path = HERE.parents[1] / "MobileNAV Configuration Example" / "src" / "Provider" / "ExampleMNProvider.Codeunit.al"
        if path.exists():
            self.assertEqual(check.parse_provider_ids(path.read_text(encoding="utf-8-sig"))[0], ["EXAMPLE"])


class Extension(unittest.TestCase):
    def vsix(self):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("extension/package.json", json.dumps({"version": "9.9.9"}))
            z.writestr("extension/bin/alc.dll", b"dll")
            z.writestr("extension.vsixmanifest", "x")
        return buf.getvalue()

    def test_extract(self):
        with tempfile.TemporaryDirectory() as d:
            dest = check.extract_extension(self.vsix(), d)
            self.assertEqual(dest.name, "ms-dynamics-smb.al-9.9.9")
            self.assertEqual((dest / "bin" / "alc.dll").read_bytes(), b"dll")
            self.assertFalse((dest / "extension.vsixmanifest").exists())

    def test_gzip_wrapper(self):
        import gzip
        self.assertEqual(check.unwrap_download(gzip.compress(b"PKdata")), b"PKdata")
        self.assertEqual(check.unwrap_download(b"PKdata"), b"PKdata")

    def test_path_escape_refused(self):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            z.writestr("extension/package.json", json.dumps({"version": "1"}))
            z.writestr("extension/../../evil", b"x")
        with tempfile.TemporaryDirectory() as d, self.assertRaises(check.Fail):
            check.extract_extension(buf.getvalue(), d)

    def test_find_tools(self):
        self.assertEqual(check.find_tools(FAKE_TOOLS)[0].name, "bcbd.py")
        self.assertEqual(check.find_tools(FAKE_TOOLS)[2].name, "mndevice.py")
        with self.assertRaises(check.Fail):
            check.find_tools(None)
        with self.assertRaises(check.Fail):
            check.find_tools("/nonexistent")


class Stamp(unittest.TestCase):
    def test_version_and_restore(self):
        with tempfile.TemporaryDirectory() as d:
            (pathlib.Path(d) / "app.json").write_text('{\n  "name": "A", "publisher": "P", "id": "1", "version": "2.0.3.0"\n}\n')
            app = check.App(d, d, stamp=41)
            self.assertEqual(app.version, "2.0.3.41")
            with check.stamped([app]):
                self.assertIn('"version": "2.0.3.41"', (pathlib.Path(d) / "app.json").read_text())
            self.assertIn('"version": "2.0.3.0"', (pathlib.Path(d) / "app.json").read_text())


def installed_dotnet_major():
    out = subprocess.run(["dotnet", "--list-runtimes"], capture_output=True, text=True).stdout
    return int(next(l for l in out.splitlines() if l.startswith("Microsoft.NETCore.App")).split()[1].split(".")[0])


class WholeRun(unittest.TestCase):
    """check.py as a process, with fake bcbd.py and mnconfig.py that print the recorded fixtures."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        tmp = pathlib.Path(self.tmp.name)
        self.app = tmp / "app"
        (self.app / "src").mkdir(parents=True)
        (self.app / "app.json").write_text(json.dumps({"id": "i", "name": "Ex", "publisher": "P", "version": "1.0.0.0"}))
        (self.app / "src" / "P.Codeunit.al").write_text(fixture("Provider.Codeunit.al").split("codeunit 50101")[0])
        self.log = tmp / "calls.log"

    def check(self, *args, runtime=None, **env):
        self.runtime = runtime if runtime is not None else installed_dotnet_major()
        e = dict(os.environ, FAKE_LOG=str(self.log), BC_TOOLS=str(FAKE_TOOLS), HOME=self.tmp.name, **env)
        for k in ("BC_CLIENT_ID", "BC_CLIENT_SECRET"):
            e.pop(k, None)
        e.update(env)
        # a compiler folder with the files setup looks for, so setup downloads nothing
        ext = pathlib.Path(self.tmp.name) / ".vscode/extensions/ms-dynamics-smb.al-1/bin"
        ext.mkdir(parents=True, exist_ok=True)
        (ext / "alc.dll").write_text("")
        (ext / "ALCops.LinterCop.dll").write_text("")
        (ext / "alc.runtimeconfig.json").write_text(json.dumps({"runtimeOptions": {"tfm": "net0", "framework": {"version": f"{self.runtime}.0.0"}}}))
        p = subprocess.run([sys.executable, str(HERE.parent / "check.py"), *args, "--app", str(self.app), "--out-dir", str(pathlib.Path(self.tmp.name) / "out"),
                            "--tenant", "T", "--env", "E", "--no-symbols"], capture_output=True, text=True, env=e)
        return p.returncode, p.stdout + p.stderr

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_dotnet_missing_runtime_is_a_failure_row(self):
        rc, out = self.check("build", runtime=0)
        self.assertEqual(rc, 1)
        self.assertIn("needs .NET 0", out)

    def run_all(self, *extra, **env):
        return self.check("all", *extra, **env)

    def test_all_green(self):
        rc, out = self.run_all()
        self.assertEqual(rc, 0, out)
        for s in ("build", "deploy", "preview", "apply", "doctor"):
            self.assertRegex(out, rf"{s}\s+ok")
        self.assertTrue(any(c.startswith("bcbd") and " upload " in c for c in self.calls()))
        self.assertTrue(any("preview EXAMPLE" in c for c in self.calls()))
        for tool, word in (("bcbd", "build"), ("bcbd", "upload"), ("mnconfig", "preview"), ("mnconfig", "apply"), ("mnconfig", "doctor")):
            matching = [c for c in self.calls() if c.startswith(tool) and f" {word}" in c]
            self.assertTrue(matching, word)
            self.assertTrue(all(c.endswith(" --json") for c in matching), word)

    def test_device_is_skipped_unless_asked_for(self):
        rc, out = self.run_all()
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"device\s+skipped\s+\d+\s+pass --device to run")
        self.assertFalse(any(c.startswith("mndevice") for c in self.calls()))

    def test_device_passes(self):
        rc, out = self.run_all("--device", "--device-profile", "CI")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"device\s+ok\s+\d+\s+EXAMPLE: 76 device checks passed")
        call = next(c for c in self.calls() if c.startswith("mndevice"))
        self.assertIn("assert --provider EXAMPLE --app ", call)
        self.assertIn("--profile CI", call)
        self.assertLess(next(i for i, c in enumerate(self.calls()) if " apply " in c), self.calls().index(call))

    def test_device_failure_names_the_first_row(self):
        rc, out = self.run_all("--device", FAKE_ASSERT="assert_failed.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"device\s+FAIL\s+\d+\s+EXAMPLE: 2 of 77 device checks failed, first: MNExampleStockCount \| LotNo \| visible")
        self.assertRegex(out, r"doctor\s+ok")

    def test_device_alone(self):
        rc, out = self.check("device", "--device")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"device\s+ok")
        rc, out = self.check("device")
        self.assertRegex(out, r"device\s+skipped")

    def test_device_skipped_after_a_failed_apply(self):
        rc, out = self.run_all("--device", FAKE_PREVIEW="preview_error.txt")
        self.assertRegex(out, r"device\s+skipped\s+\d+\s+apply failed")
        self.assertFalse(any(c.startswith("mndevice") for c in self.calls()))

    def test_no_deploy_skips_upload(self):
        rc, out = self.run_all("--no-deploy", "--no-apply")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"deploy\s+skipped\s+\d+\s+--no-deploy")
        self.assertRegex(out, r"apply\s+skipped\s+\d+\s+--no-apply")
        self.assertFalse(any(" upload " in c for c in self.calls()))
        self.assertFalse(any(" apply " in c for c in self.calls()))

    def test_diagnostics_fail_and_skip_the_rest(self):
        rc, out = self.run_all(FAKE_BUILD="build_diagnostics.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"build\s+FAIL")
        self.assertRegex(out, r"preview\s+skipped\s+\d+\s+build failed")
        self.assertFalse(any("mnconfig" in c for c in self.calls()))

    def test_build_without_json_line_fails(self):
        rc, out = self.run_all(FAKE_BUILD="build_no_json.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"build\s+FAIL")
        self.assertIn("no summary line from bcbd.py build", out)

    def test_missing_analyzer_fails(self):
        rc, out = self.run_all(FAKE_BUILD="build_compile_error.txt")
        self.assertEqual(rc, 1)
        self.assertIn("analyzers missing", out)

    def test_preview_error_line_fails_and_blocks_apply(self):
        rc, out = self.run_all(FAKE_PREVIEW="preview_error.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"preview\s+FAIL")
        self.assertRegex(out, r"apply\s+skipped\s+\d+\s+preview failed")
        self.assertRegex(out, r"doctor\s+ok")

    def test_doctor_warning_fails(self):
        rc, out = self.run_all(FAKE_DOCTOR="doctor_findings.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"doctor\s+FAIL.*2 findings at Warning or above")

    def test_doctor_info_only_passes(self):
        rc, out = self.run_all("--fail-on", "Blocker", FAKE_DOCTOR="doctor_findings.txt")
        self.assertEqual(rc, 1)
        rc, out = self.check("doctor", "--fail-on", "Blocker", FAKE_DOCTOR="doctor_clean.txt")
        self.assertEqual(rc, 0, out)

    def test_upload_failure_skips_preview(self):
        rc, out = self.run_all(FAKE_UPLOAD="upload_failed.txt")
        self.assertEqual(rc, 1)
        self.assertRegex(out, r"deploy\s+FAIL")
        self.assertRegex(out, r"doctor\s+skipped\s+\d+\s+deploy failed")

    def test_unregistered_provider_fails_preview(self):
        rc, out = self.run_all(FAKE_PROVIDERS="[]")
        self.assertEqual(rc, 1)
        self.assertIn("does not list provider EXAMPLE", out)

    def test_client_id_without_secret(self):
        rc, out = self.check("build", BC_CLIENT_ID="abc")
        self.assertEqual(rc, 1)
        self.assertIn("BC_CLIENT_SECRET", out)

    def test_login_with_application(self):
        rc, out = self.check("doctor", BC_CLIENT_ID="abc", BC_CLIENT_SECRET="s3cret")
        self.assertEqual(rc, 0, out)
        login = [c for c in self.calls() if " login " in c][0]
        self.assertIn("--app --client-id abc --secret-env BC_CLIENT_SECRET", login)
        self.assertNotIn("s3cret", self.log.read_text())
        self.assertNotIn("s3cret", out)



if __name__ == "__main__":
    unittest.main()
