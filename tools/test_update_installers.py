#!/usr/bin/env python3
"""Native installer checks; no engine, downloads, or player-side Python dependency."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "game/tools/updater/apply_update.sh"
POWERSHELL = ROOT / "game/tools/updater/apply_update.ps1"
PWSH = shutil.which("pwsh")
PYTHON_BYTES = Path(sys.executable).read_bytes()
OLD = PYTHON_BYTES + b"\nHullwatch old fixture\n"
NEW = PYTHON_BYTES + b"\nHullwatch new fixture\n"
ARGS = ["", "two words", 'quote"here', "single'quote", "trailing\\", 'slashes\\\\"quote',
        "$(touch injected)", "`touch injected`", "; touch injected", "&|<>^%!*?", "snowman \u2603"]


class InstallerChecks:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Hullwatch installer spaces ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.target = self.root / "Hullwatch playtest.exe"
        self.stage = self.root / ".hullwatch-update"
        self.stage.mkdir()
        self.payload = self.stage / "payload"
        self.previous = self.stage / "previous"
        self.backup = self.previous / self.target.name
        self.target.write_bytes(OLD)
        self.target.chmod(0o755)
        self.payload.write_bytes(NEW)
        self.payload.chmod(0o755)
        self.saved = self.root / "saves" / "slot_1.json"
        self.saved.parent.mkdir()
        self.saved.write_text('{"keep": true}')
        self.unrelated = self.root / "keep.dat"
        self.unrelated.write_bytes(b"unchanged")
        self.record = self.root / "argv result.json"
        self.env = dict(os.environ, PYTHONHOME=sys.base_prefix)
        self.env["PATH"] = str(Path(sys.executable).parent) + os.pathsep + self.env.get("PATH", "")

    def handoff(self, pid=2147483647):
        download = self.stage / "download.lock"
        download.mkdir(exist_ok=True)
        (download / "owner_pid").write_text(str(pid))
        (self.stage / "handoff").write_text(str(pid))

    def argv(self, extra=ARGS):
        return ["-c", "import json,pathlib,sys; pathlib.Path(sys.argv[1]).write_text(json.dumps(sys.argv[2:]))",
                str(self.record), *extra]

    def command(self, *, target=None, payload=None, sha=None, size=None, pid=0, launch=False, args=None):
        if not (self.stage / "handoff").exists():
            self.handoff(pid if pid > 0 else 2147483647)
        target = str(self.target if target is None else target)
        payload = str(self.payload if payload is None else payload)
        sha = hashlib.sha256(NEW).hexdigest() if sha is None else sha
        size = str(len(NEW) if size is None else size)
        if self.kind == "shell":
            mode = ["--", *(self.argv() if args is None else args)] if launch else ["--no-launch"]
            return ["sh", str(SHELL), target, payload, sha, size, str(pid), *mode]
        restart = self.root / "restart arguments.json"
        restart.write_text(json.dumps(self.argv() if args is None else args), encoding="utf-8")
        return [PWSH, "-NoProfile", "-NonInteractive", "-File", str(POWERSHELL),
                "-Target", target, "-Payload", payload, "-Sha256", sha, "-Size", size,
                "-WaitPid", str(pid), "-RestartArgsJson", str(restart)]

    def run_installer(self, **kwargs):
        result = subprocess.run(self.command(**kwargs), env=self.env, cwd=self.root,
                                capture_output=True, text=True, timeout=40)
        self.assertEqual(self.saved.read_text(), '{"keep": true}')
        self.assertEqual(self.unrelated.read_bytes(), b"unchanged")
        self.assertFalse((self.root / "injected").exists())
        return result

    def refusal(self, **kwargs):
        result = self.run_installer(**kwargs)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.target.read_bytes(), OLD)
        return result

    def sleeper(self, seconds):
        child = subprocess.Popen([sys.executable, "-c", f"import time; time.sleep({seconds})"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        def finish():
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=5)
        self.addCleanup(finish)
        return child

    def test_success_and_previous_retained(self):
        self.previous.mkdir()
        self.backup.write_bytes(b"older build")
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.target.read_bytes(), NEW)
        self.assertEqual(self.backup.read_bytes(), OLD)
        self.assertFalse(self.payload.exists())
        self.assertFalse((self.stage / "apply.lock").exists())
        self.assertFalse((self.stage / "download.lock").exists())
        self.assertTrue((self.stage / "pending").exists())
        self.assertTrue((self.stage / "handoff").exists())
        self.assertEqual((self.stage / "expected-new.sha256").read_text().strip(), hashlib.sha256(NEW).hexdigest())
        self.assertEqual(Path(str(self.backup) + ".sha256").read_text().strip(), hashlib.sha256(OLD).hexdigest())
        self.assertTrue(os.access(self.target, os.X_OK))

    def test_literal_argv_forwarding(self):
        result = self.run_installer(launch=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        deadline = time.monotonic() + 5
        while not self.record.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertTrue(self.record.exists(), result.stdout + result.stderr)
        self.assertEqual(json.loads(self.record.read_text()), ARGS)

    def test_sha_and_size_refusal(self):
        for params in ({"sha": "0" * 64}, {"size": len(NEW) + 1},
                       {"sha": hashlib.sha256(NEW).hexdigest().upper()},
                       {"sha": "a" * 63}, {"sha": "a" * 64 + "\n"}, {"size": 0},
                       {"size": -1}, {"size": 9223372036854775808}, {"pid": -1}):
            with self.subTest(params=params):
                self.refusal(**params)
                self.assertEqual(self.payload.read_bytes(), NEW)
                self.assertFalse(self.backup.exists())

    def test_wait_timeout_does_not_kill(self):
        child = self.sleeper(60)
        started = time.monotonic()
        result = self.refusal(pid=child.pid)
        elapsed = time.monotonic() - started
        self.assertIn("timeout", result.stderr.lower())
        self.assertGreaterEqual(elapsed, 28)
        self.assertLess(elapsed, 35)
        self.assertIsNone(child.poll())
        self.assertFalse(self.backup.exists())

    def test_recheck_after_wait(self):
        child = self.sleeper(1.5)
        # Reap the fixture so Linux does not conservatively wait on its zombie PID.
        reaper = threading.Thread(target=child.wait)
        reaper.start()
        mutation = threading.Timer(0.7, lambda: self.payload.write_bytes(NEW[:-1] + b"X"))
        mutation.start()
        try:
            self.refusal(pid=child.pid)
        finally:
            mutation.join()
            reaper.join()
        self.assertFalse(self.backup.exists())

    def test_recheck_size_after_wait(self):
        child = self.sleeper(1.5)
        reaper = threading.Thread(target=child.wait)
        reaper.start()
        mutation = threading.Timer(0.7, lambda: self.payload.write_bytes(NEW + b"X"))
        mutation.start()
        try:
            self.refusal(pid=child.pid)
        finally:
            mutation.join()
            reaper.join()

    def test_path_traversal_and_nonfixed_payload(self):
        other = self.root / "other payload"
        other.write_bytes(NEW)
        for params in ({"payload": other}, {"payload": "relative/payload"},
                       {"target": self.target.name},
                       {"payload": str(self.stage) + "/../.hullwatch-update/payload"},
                       {"target": str(self.root) + "/./" + self.target.name}):
            with self.subTest(params=params):
                self.refusal(**params)
        self.assertEqual(other.read_bytes(), NEW)

    def test_target_must_be_regular_and_existing(self):
        self.target.unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.target.mkdir()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.target.is_dir())
        self.assertEqual(self.payload.read_bytes(), NEW)

    def test_symlinks_refused(self):
        if os.name == "nt":
            probe = self.root / "symlink probe"
            try:
                probe.symlink_to(self.target)
            except OSError as error:
                self.skipTest(f"Windows symlinks unavailable: {error}")
            probe.unlink()
        outside = self.root / "outside file"
        outside.write_bytes(NEW)
        self.payload.unlink()
        self.payload.symlink_to(outside)
        self.refusal()
        self.payload.unlink()
        self.payload.write_bytes(NEW)
        self.target.unlink()
        self.target.symlink_to(outside)
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(outside.read_bytes(), NEW)
        self.target.unlink()
        self.target.write_bytes(OLD)
        self.payload.unlink()
        shutil.rmtree(self.stage)
        outside_stage = self.root / "outside staging"
        outside_stage.mkdir()
        (outside_stage / "payload").write_bytes(NEW)
        self.stage.symlink_to(outside_stage, target_is_directory=True)
        self.refusal()
        self.assertEqual((outside_stage / "payload").read_bytes(), NEW)

    def test_symlink_ancestor_and_backup_refused(self):
        alias = self.root / "directory alias"
        try:
            alias.symlink_to(self.root, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"Symlinks unavailable: {error}")
        self.refusal(target=alias / self.target.name, payload=alias / ".hullwatch-update/payload")
        self.previous.mkdir()
        outside = self.root / "outside backup"
        outside.write_bytes(b"keep backup")
        self.backup.symlink_to(outside)
        self.refusal()
        self.assertEqual(outside.read_bytes(), b"keep backup")
        self.backup.unlink()
        self.previous.rmdir()
        self.previous.symlink_to(self.root, target_is_directory=True)
        self.refusal()

    def test_stale_lock_refused(self):
        lock = self.stage / "apply.lock"
        lock.mkdir()
        (lock / "owner_pid").write_text(str(os.getpid()))
        self.refusal()
        self.assertTrue(lock.exists())

    def recover(self):
        command = (["sh", str(SHELL), "--recover", str(self.target)] if self.kind == "shell" else
                   [PWSH, "-NoProfile", "-NonInteractive", "-File", str(POWERSHELL), "-Recover", "-Target", str(self.target)])
        return subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=10)

    def interrupted(self):
        self.handoff()
        self.previous.mkdir(exist_ok=True)
        self.backup.write_bytes(OLD)
        self.backup.chmod(0o755)
        Path(str(self.backup) + ".sha256").write_text(hashlib.sha256(OLD).hexdigest())
        (self.stage / "expected-new.sha256").write_text(hashlib.sha256(NEW).hexdigest())
        (self.stage / "pending").write_text(hashlib.sha256(NEW).hexdigest())
        lock = self.stage / "apply.lock"
        lock.mkdir(exist_ok=True)
        (lock / "owner_pid").write_text("2147483647")

    def test_recovery_preserves_old_and_new_and_is_idempotent(self):
        for current in (OLD, NEW):
            with self.subTest(current="old" if current == OLD else "new"):
                self.interrupted()
                self.target.write_bytes(current)
                self.payload.write_bytes(NEW)
                result = self.recover()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.target.read_bytes(), current)
                self.assertEqual(self.backup.read_bytes(), OLD)
                for name in ("handoff", "payload", "download.lock", "apply.lock"):
                    self.assertFalse((self.stage / name).exists(), name)
                self.assertEqual((self.stage / "pending").exists(), current == NEW)
                result = self.recover()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.target.read_bytes(), current)
                self.assertFalse(self.record.exists())

    def test_recovery_restores_missing_or_invalid_only_from_verified_prior(self):
        for missing in (False, True):
            with self.subTest(missing=missing):
                self.interrupted()
                if missing:
                    self.target.unlink()
                else:
                    self.target.write_bytes(b"corrupt executable")
                result = self.recover()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.target.read_bytes(), OLD)
                self.assertEqual(self.backup.read_bytes(), OLD)
                self.assertFalse(self.payload.exists())
                self.assertFalse(self.record.exists())

    def test_recovery_refuses_unverified_backup(self):
        self.interrupted()
        self.target.write_bytes(b"invalid current")
        self.backup.write_bytes(b"invalid prior")
        result = self.recover()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.target.read_bytes(), b"invalid current")
        self.assertTrue((self.stage / "handoff").exists())
        self.assertEqual(self.payload.read_bytes(), NEW)

    def test_recovery_before_backup_receipt_publication(self):
        current = b"last installed build"
        self.interrupted()
        self.target.write_bytes(current)
        self.backup.write_bytes(current)
        Path(str(self.backup) + ".sha256").unlink()
        (self.stage / "expected-old.sha256").write_text(hashlib.sha256(current).hexdigest())
        result = self.recover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), current)
        self.handoff()
        self.target.write_bytes(b"corrupt")
        result = self.recover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), current)

    def test_recovery_without_handoff_is_noop(self):
        result = self.recover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), OLD)
        self.assertEqual(self.payload.read_bytes(), NEW)

    def test_recovery_refuses_live_download_owner(self):
        self.interrupted()
        (self.stage / "download.lock/owner_pid").write_text(str(os.getpid()))
        result = self.recover()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.stage / "download.lock/owner_pid").read_text(), str(os.getpid()))
        self.assertTrue((self.stage / "handoff").exists())
        self.assertEqual(self.target.read_bytes(), OLD)

    def test_unrelated_download_owner_is_retained(self):
        self.handoff(os.getpid())
        self.refusal(pid=2147483647)
        self.assertEqual((self.stage / "download.lock/owner_pid").read_text(), str(os.getpid()))
        self.assertTrue((self.stage / "handoff").exists())


@unittest.skipUnless(os.name == "posix" and sys.platform.startswith("linux"), "Linux helper requires Linux")
class ShellTests(InstallerChecks, unittest.TestCase):
    kind = "shell"

    def test_no_launch(self):
        self.payload.chmod(0o600)
        result = self.run_installer(launch=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.record.exists())
        self.assertTrue(os.access(self.target, os.X_OK))

    def test_nonzero_game_exit_preserves_valid_new_build(self):
        result = self.run_installer(launch=True, args=["-c", "import sys; sys.exit(7)"])
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(self.target.read_bytes(), NEW)
        self.assertTrue((self.stage / "pending").exists())
        result = self.recover()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), NEW)
        self.assertTrue((self.stage / "pending").exists())

    def test_copy_move_and_chmod_failures(self):
        for failing in ("cp", "backup-mv", "target-mv", "chmod"):
            with self.subTest(command=failing):
                if (self.stage / "handoff").exists():
                    recovery = self.recover()
                    self.assertEqual(recovery.returncode, 0, recovery.stderr)
                self.target.write_bytes(OLD)
                self.payload.write_bytes(NEW)
                self.previous.mkdir(exist_ok=True)
                self.backup.write_bytes(b"older build")
                wrappers = self.root / "failing commands"
                wrappers.mkdir(exist_ok=True)
                command = "mv" if failing.endswith("-mv") else failing
                original = shutil.which(command)
                wrapper = wrappers / command
                # Failure injection damages only cp's temporary destination.
                body = "exit 1\n"
                if failing == "cp":
                    body = 'for last do :; done\nprintf partial > "$last"\nexit 1\n'
                elif failing == "backup-mv":
                    body = 'case "$4" in */previous/*) exit 1;; esac\nexec "$REAL_COMMAND" "$@"\n'
                elif failing == "target-mv":
                    body = 'case "$3" in */payload) exit 1;; esac\nexec "$REAL_COMMAND" "$@"\n'
                wrapper.write_text("#!/bin/sh\n" + body)
                wrapper.chmod(0o755)
                old_env = self.env.copy()
                self.env["REAL_COMMAND"] = original
                self.env["PATH"] = str(wrappers) + os.pathsep + old_env["PATH"]
                try:
                    self.refusal()
                    expected = b"older build" if failing in ("cp", "backup-mv") else OLD
                    self.assertEqual(self.backup.read_bytes(), expected)
                    self.assertFalse(list(self.previous.glob(".previous.*")))
                finally:
                    self.env = old_env
                    wrapper.unlink()

    def test_other_filesystem_refused(self):
        ram = Path("/dev/shm")
        if not ram.is_dir() or ram.stat().st_dev == self.root.stat().st_dev:
            self.skipTest("No separate temporary filesystem")
        with tempfile.NamedTemporaryFile(dir=ram) as remote:
            remote.write(NEW)
            remote.flush()
            self.payload.unlink()
            # A bind mount needs privileges; test an external filesystem path directly.
            self.refusal(payload=remote.name)

    def test_staged_device_mismatch_refused(self):
        wrappers = self.root / "device check commands"
        wrappers.mkdir()
        wrapper = wrappers / "stat"
        wrapper.write_text('#!/bin/sh\nif [ "$2" = %d ] && [ "$4" = "$STAGED_PAYLOAD" ]; then\n'
                           '    printf "different-device\\n"\nelse\n    exec "$REAL_STAT" "$@"\nfi\n')
        wrapper.chmod(0o755)
        self.env["REAL_STAT"] = shutil.which("stat")
        self.env["STAGED_PAYLOAD"] = str(self.payload)
        self.env["PATH"] = str(wrappers) + os.pathsep + self.env["PATH"]
        result = self.refusal()
        self.assertIn("filesystem", result.stderr)
        self.assertEqual(self.payload.read_bytes(), NEW)
        self.assertFalse(self.backup.exists())

    def test_killed_helper_recovers_before_and_after_swap(self):
        import signal
        wrappers = self.root / "interrupt commands"
        wrappers.mkdir()
        wrapper = wrappers / "mv"
        wrapper.write_text('#!/bin/sh\nif [ "$3" = "$STAGED_PAYLOAD" ]; then\n'
                           '    if [ "$INTERRUPT_PHASE" = after ]; then "$REAL_MV" "$@" || exit; fi\n'
                           '    printf "%s" "$$" > "$INTERRUPT_POINT"\n'
                           '    exec sleep 60\nfi\nexec "$REAL_MV" "$@"\n')
        wrapper.chmod(0o755)
        self.env["REAL_MV"] = shutil.which("mv")
        self.env["STAGED_PAYLOAD"] = str(self.payload)
        pause = self.root / "interrupt point"
        self.env["INTERRUPT_POINT"] = str(pause)
        self.env["PATH"] = str(wrappers) + os.pathsep + self.env["PATH"]
        for phase in ("before", "after"):
            with self.subTest(phase=phase):
                self.target.write_bytes(OLD)
                self.payload.write_bytes(NEW)
                self.payload.chmod(0o755)
                self.env["INTERRUPT_PHASE"] = phase
                helper = subprocess.Popen(self.command(), env=self.env,
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                child_pid = None
                try:
                    deadline = time.monotonic() + 5
                    while not pause.exists() and helper.poll() is None and time.monotonic() < deadline:
                        time.sleep(0.02)
                    self.assertTrue(pause.exists(), f"helper exit: {helper.poll()}")
                    child_pid = int(pause.read_text())
                    helper.kill()
                    helper.wait(timeout=5)
                    os.kill(child_pid, signal.SIGKILL)
                    child_pid = None
                    result = self.recover()
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(self.target.read_bytes(), OLD if phase == "before" else NEW)
                    self.assertEqual(self.backup.read_bytes(), OLD)
                    self.assertFalse(self.payload.exists())
                    self.assertFalse(self.record.exists())
                    self.assertFalse((self.stage / "handoff").exists())
                finally:
                    if helper.poll() is None:
                        helper.kill()
                    helper.wait(timeout=5)
                    if child_pid is not None:
                        os.kill(child_pid, signal.SIGKILL)
                    pause.unlink(missing_ok=True)


@unittest.skipUnless(PWSH, "Windows execution unavailable: pwsh is not installed")
class PowerShellTests(InstallerChecks, unittest.TestCase):
    kind = "powershell"

    def test_invalid_restart_json(self):
        for value in ("text", [1], [None], [["nested"]], {"key": "value"}, ["nul\u0000"]):
            with self.subTest(value=value):
                self.refusal(args=value)

    def test_empty_restart_array(self):
        # Validate [] without launching a long-running interpreter console.
        command = self.command(args=[])
        command[command.index("-Sha256") + 1] = "0" * 64
        result = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SHA256 mismatch", result.stderr)
        self.assertEqual(self.target.read_bytes(), OLD)

    def test_malformed_restart_json(self):
        for raw in ('[], "extra": true', '["one"],"arguments":["two"]', '[', ''):
            with self.subTest(raw=raw):
                command = self.command()
                restart = Path(command[command.index("-RestartArgsJson") + 1])
                restart.write_text(raw)
                result = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=10)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.target.read_bytes(), OLD)

    def test_launch_failure_restores_old_and_retains_backup(self):
        bad = b"This is not a native executable.\n"
        self.payload.write_bytes(bad)
        result = self.refusal(sha=hashlib.sha256(bad).hexdigest(), size=len(bad))
        self.assertEqual(self.backup.read_bytes(), OLD)
        self.assertFalse(list(self.previous.glob(".restore-*")))
        self.assertIn("Hullwatch update", result.stderr)

    @unittest.skipUnless(os.name == "nt", "Windows File.Replace sharing failure requires Windows")
    def test_replace_failure_retains_old(self):
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                      wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        self.previous.mkdir()
        self.backup.write_bytes(b"older build")
        handle = kernel.CreateFileW(str(self.target), 0x80000000, 1, None, 3, 0x80, None)
        self.assertNotEqual(handle, wintypes.HANDLE(-1).value, ctypes.get_last_error())
        try:
            self.refusal()
            self.assertEqual(self.backup.read_bytes(), OLD)
        finally:
            kernel.CloseHandle(handle)


if __name__ == "__main__":
    if not PWSH:
        print("Windows execution unavailable: pwsh is not installed.", flush=True)
    elif os.name != "nt":
        print("pwsh found; PowerShell checks run here, native Windows execution unavailable.", flush=True)
    unittest.main(verbosity=2)
