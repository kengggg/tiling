"""Behavioral tests. All file writes use temporary directories; apps are stubbed."""
from pathlib import Path
import os
import json
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="tiling-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.user_dir = self.base / "user with spaces"
        self.repo = self.base / "source clone"
        self.stage = self.base / "stage"
        self.xdg = self.base / "custom config"
        for p in (self.user_dir, self.repo, self.stage):
            p.mkdir()
        shutil.copy2(ROOT / "aerospace.toml", self.repo / "aerospace.toml")
        shutil.copytree(ROOT / "sketchybar", self.repo / "sketchybar")
        self.env = dict(os.environ, TEST_USER_DIR=str(self.user_dir),
                        TEST_REPO=str(self.repo), TEST_STAGE=str(self.stage),
                        TEST_XDG=str(self.xdg), TEST_LOG=str(self.base / "calls"))
        self.preamble = f'''source {shlex.quote(str(ROOT / 'install.sh'))}
init_paths "$TEST_USER_DIR" "$TEST_REPO" "$TEST_XDG"
WORK_DIR="$TEST_STAGE"
REPLACE_CONFIG=0
CHECK_ONLY=0
NO_START=1
SETTINGS_MODE=skip
'''

    def shell(self, code, success=True):
        result = subprocess.run(["/bin/bash", "-c", self.preamble + code],
                                env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def install(self):
        self.shell("check_source; confirm_replacement; install_configs")

    def test_first_install_and_repeat_are_identical_without_backups(self):
        self.install()
        self.shell("confirm() { return 99; }; confirm_replacement; install_configs; bar_current")
        self.assertEqual((self.user_dir / ".aerospace.toml").read_bytes(),
                         (self.repo / "aerospace.toml").read_bytes())
        for source in (self.repo / "sketchybar").rglob("*"):
            if source.is_file():
                live = self.user_dir / ".config/sketchybar" / source.relative_to(self.repo / "sketchybar")
                self.assertEqual(source.read_bytes(), live.read_bytes())
                self.assertTrue(os.access(live, os.X_OK))
        self.assertEqual(list(self.user_dir.rglob("*.bak-*")), [])

    def test_declining_replacement_leaves_configs_untouched(self):
        live = self.user_dir / ".aerospace.toml"
        live.write_text("my existing settings")
        self.shell("confirm() { return 1; }; confirm_replacement; install_configs", success=False)
        self.assertEqual(live.read_text(), "my existing settings")
        self.assertFalse((self.user_dir / ".config").exists())

    def test_alternate_configs_are_backed_up_before_replacement(self):
        for path in [self.user_dir / ".config/aerospace/aerospace.toml", self.xdg / "aerospace/aerospace.toml"]:
            path.parent.mkdir(parents=True)
            path.write_text("alternate")
        self.shell("REPLACE_CONFIG=1; confirm_replacement; install_configs")
        for directory in [self.user_dir / ".config/aerospace", self.xdg / "aerospace"]:
            self.assertFalse((directory / "aerospace.toml").exists())
            backups = list(directory.glob("aerospace.toml.bak-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), "alternate")

    def test_custom_bar_files_require_confirmation_and_are_backed_up(self):
        self.install()
        live = self.user_dir / ".config/sketchybar"
        (live / "personal.json").write_text("personal")
        self.shell("confirm() { return 1; }; confirm_replacement", success=False)
        self.shell("REPLACE_CONFIG=1; confirm_replacement; install_configs; bar_current")
        backup = next(live.parent.glob("sketchybar.bak-*"))
        self.assertEqual((backup / "personal.json").read_text(), "personal")
        self.assertFalse((live / "personal.json").exists())

    def test_backup_timestamp_collision_keeps_both_versions(self):
        self.shell('''TS=fixed
printf first > "$LIVE_AERO"
backup_path "$LIVE_AERO"
printf second > "$LIVE_AERO"
backup_path "$LIVE_AERO"
''')
        self.assertEqual((self.user_dir / ".aerospace.toml.bak-fixed").read_text(), "first")
        self.assertEqual((self.user_dir / ".aerospace.toml.bak-fixed-1").read_text(), "second")

    def test_linked_plugin_directory_is_copied_and_backup_survives_clone_removal(self):
        live = self.user_dir / ".config/sketchybar"
        live.mkdir(parents=True)
        shutil.copy2(self.repo / "sketchybar/sketchybarrc", live / "sketchybarrc")
        (live / "plugins").symlink_to(self.repo / "sketchybar/plugins", target_is_directory=True)
        self.shell("if bar_current; then exit 1; fi; install_configs; bar_current")
        backup = next(live.parent.glob("sketchybar.bak-*"))
        shutil.rmtree(self.repo)
        self.assertFalse((live / "plugins").is_symlink())
        self.assertFalse((backup / "plugins").is_symlink())
        self.assertTrue((backup / "plugins/aerospace.sh").is_file())

    def test_top_level_symlink_backup_is_a_real_copy(self):
        live = self.user_dir / ".aerospace.toml"
        live.symlink_to(self.repo / "aerospace.toml")
        self.shell('backup_path "$LIVE_AERO"')
        backup = next(self.user_dir.glob(".aerospace.toml.bak-*"))
        shutil.rmtree(self.repo)
        self.assertFalse(backup.is_symlink())
        self.assertIn("config-version", backup.read_text())

    def test_failed_backup_does_not_remove_original(self):
        live = self.user_dir / ".aerospace.toml"
        live.write_text("original")
        self.shell('cp() { return 1; }; backup_path "$LIVE_AERO"', success=False)
        self.assertEqual(live.read_text(), "original")
        self.assertEqual(list(self.user_dir.glob("*.bak-*")), [])

    def test_failed_replacement_restores_original(self):
        live = self.user_dir / ".aerospace.toml"
        live.write_text("original")
        self.shell('''printf replacement > "$WORK_DIR/new"
mv() { if [ "$1" = "$WORK_DIR/new" ]; then return 1; fi; command mv "$@"; }
replace_path "$WORK_DIR/new" "$LIVE_AERO"
''', success=False)
        self.assertEqual(live.read_text(), "original")

    def test_missing_source_aborts_before_changes(self):
        (self.repo / "aerospace.toml").unlink()
        live = self.user_dir / ".aerospace.toml"
        live.write_text("original")
        self.shell("check_source; install_configs", success=False)
        self.assertEqual(live.read_text(), "original")

    def test_version_comparison(self):
        for version, expected in [("0.20.3", False), ("0.21.0", True), ("0.21.3", True),
                                  ("0.100.0", True), ("1.0.0", True), ("unknown", False)]:
            with self.subTest(version=version):
                self.shell(f"version_at_least {shlex.quote(version)} 0.21.0", success=expected)

    def test_old_aerospace_refusal_does_not_change_configs(self):
        result = self.shell('''aerospace() { printf 'aerospace CLI client version: 0.20.3-Beta\n'; }
confirm() { return 1; }
check_versions
install_configs
''', success=False)
        self.assertIn("No configurations were changed", result.stderr)
        self.assertFalse((self.user_dir / ".aerospace.toml").exists())

    def test_old_sketchybar_is_detected_without_prompt_in_check_mode(self):
        self.shell('''aerospace() { printf 'aerospace CLI client version: 0.21.3-Beta\n'; }
sketchybar() { printf 'sketchybar-v2.20.0\n'; }
confirm() { printf prompted > "$TEST_LOG"; }
CHECK_ONLY=1
check_versions
''', success=False)
        self.assertFalse((self.base / "calls").exists())

    def test_platform_gate(self):
        for system, arch, version, uid, ok in [
            ("Darwin", "arm64", "27.0", "501", True),
            ("Darwin", "arm64", "28.0", "501", True),
            ("Darwin", "arm64", "26.0", "501", False),
            ("Darwin", "x86_64", "27.0", "501", False),
            ("Linux", "arm64", "27.0", "501", False),
            ("Darwin", "arm64", "27.0", "0", False),
        ]:
            with self.subTest(system=system, arch=arch, version=version, uid=uid):
                self.shell(f'''id() {{ printf '{uid}'; }}
uname() {{ if [ "$1" = -s ]; then printf '{system}'; else printf '{arch}'; fi; }}
sw_vers() {{ printf '{version}'; }}
check_platform
''', success=ok)

    def test_first_launch_opens_aerospace(self):
        self.shell('''aerospace() {
  if [ "$1" = list-monitors ]; then [ -f "$WORK_DIR/started" ]; else printf 'aerospace %s\n' "$*" >> "$TEST_LOG"; fi
}
open() { printf 'open %s\n' "$*" >> "$TEST_LOG"; touch "$WORK_DIR/started"; }
ensure_bar_service() { :; }
check_bar_state() { return 0; }
sketchybar() { printf 'sketchybar %s\n' "$*" >> "$TEST_LOG"; }
sleep() { :; }
start_apps
''')
        calls = (self.base / "calls").read_text()
        self.assertIn("open -a AeroSpace", calls)
        self.assertIn("sketchybar --reload", calls)

    def test_running_aerospace_registers_missing_bar_service(self):
        self.shell('''aerospace() { printf 'aerospace %s\n' "$*" >> "$TEST_LOG"; }
pgrep() { return 1; }
open() { return 99; }
BREW=brew_stub
brew_stub() { printf 'brew %s\n' "$*" >> "$TEST_LOG"; }
bar_service_running() { return 1; }
pkill() { printf 'stop unmanaged\n' >> "$TEST_LOG"; }
check_bar_state() { return 0; }
sketchybar() { return 0; }
sleep() { :; }
start_apps
wait
''')
        calls = (self.base / "calls").read_text()
        self.assertIn("aerospace reload-config --no-gui", calls)
        self.assertIn("brew services stop sketchybar", calls)
        self.assertIn("stop unmanaged", calls)
        self.assertIn("brew services start sketchybar", calls)

    def test_main_no_start_installs_only_into_test_directories(self):
        self.shell('''eval "$(declare -f init_paths | sed '1s/init_paths/original_init_paths/')"
init_paths() { original_init_paths "$TEST_USER_DIR" "$TEST_REPO" "$TEST_XDG"; }
check_platform() { :; }
ensure_brew() { :; }
install_packages() { :; }
check_versions() { :; }
start_apps() { printf started > "$TEST_LOG"; }
main --no-start --skip-settings
''')
        self.assertTrue((self.user_dir / ".aerospace.toml").exists())
        self.assertFalse((self.base / "calls").exists())

    def test_bootstrap_from_stdin_downloads_complete_archive_and_forwards_flags(self):
        package = self.base / "package/tiling-main"
        package.mkdir(parents=True)
        (package / "install.sh").write_text('printf "%s\\n" "$@" > "$TEST_LOG"\n')
        archive = self.base / "fixture.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname="tiling-main")
        stubs = f'''id() {{ printf 501; }}
uname() {{ if [ "$1" = -s ]; then printf Darwin; else printf arm64; fi; }}
curl() {{ while [ "$1" != -o ]; do shift; done; cp {shlex.quote(str(archive))} "$2"; }}
'''
        code = stubs + (ROOT / "bootstrap.sh").read_text()
        result = subprocess.run(["/bin/bash", "-s", "--", "--no-start"], input=code,
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.base / "calls").read_text(), "--no-start\n")

    def test_bootstrap_stops_on_download_failure(self):
        code = '''id() { printf 501; }
uname() { if [ "$1" = -s ]; then printf Darwin; else printf arm64; fi; }
curl() { return 22; }
tar() { printf unexpected > "$TEST_LOG"; }
''' + (ROOT / "bootstrap.sh").read_text()
        result = subprocess.run(["/bin/bash"], input=code, env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 22)
        self.assertFalse((self.base / "calls").exists())

    def plugin(self, name, stubs, variables="", argument=""):
        # Plugins execute in their own normal shell, without the installer's flags.
        script = ROOT / "sketchybar/plugins" / name
        code = stubs + '\nsketchybar() { printf "<%s>" "$@"; }\n' + variables
        code += '\nsource ' + shlex.quote(str(script)) + ' ' + argument
        result = subprocess.run(["/bin/bash", "-c", code], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_desktop_battery_is_hidden(self):
        output = self.plugin("battery.sh", 'pmset() { printf "Now drawing from \'AC Power\'\\n"; }', "NAME=battery")
        self.assertIn("<drawing=off>", output)
        self.assertNotIn("label=", output)

    def test_laptop_battery_shows_percentage(self):
        output = self.plugin("battery.sh", 'pmset() { printf "Now drawing from \'Battery Power\'\\n -InternalBattery-0 85%%; discharging\\n"; }', "NAME=battery")
        self.assertIn("<drawing=on>", output)
        self.assertIn("<label=85%>", output)

    def test_wifi_detects_en1_instead_of_ethernet_en0(self):
        output = self.plugin("wifi.sh", '''networksetup() { printf 'Hardware Port: Ethernet\nDevice: en0\n\nHardware Port: Wi-Fi\nDevice: en1\n'; }
ipconfig() { if [ "$2" = en1 ]; then printf 'LinkStatusActive : TRUE\n'; else return 1; fi; }
''', "NAME=wifi")
        self.assertIn("<drawing=on>", output)
        self.assertIn("<label.drawing=off>", output)

    def test_wifi_without_adapter_is_hidden(self):
        output = self.plugin("wifi.sh", 'networksetup() { :; }', "NAME=wifi")
        self.assertIn("<drawing=off>", output)

    def test_workspace_highlight_initializes_without_event(self):
        output = self.plugin("aerospace.sh", 'aerospace() { if [ "$1" = list-modes ]; then printf main; else printf 7; fi; }',
                             "unset FOCUSED_WORKSPACE")
        self.assertIn("<space.7><background.drawing=on>", output)

    def test_workspace_event_takes_precedence_over_query(self):
        output = self.plugin("aerospace.sh", 'aerospace() { if [ "$1" = list-modes ]; then printf main; else return 99; fi; }',
                             "FOCUSED_WORKSPACE=6")
        self.assertIn("<space.6><background.drawing=on>", output)
        self.assertIn("<space.3><background.drawing=off>", output)

    def test_bar_quotes_plugin_paths_with_spaces(self):
        script = ROOT / "sketchybar/sketchybarrc"
        result = subprocess.run(["/bin/bash", "-c", f'''aerospace() {{ printf '1\n2\n'; }}
sketchybar() {{ printf '<%s>' "$@"; }}
CONFIG_DIR="$TEST_USER_DIR/.config/sketchybar"
source {shlex.quote(str(script))}
'''], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'<script="{self.user_dir}/.config/sketchybar/plugins/clock.sh">', result.stdout)

    def test_offline_aerospace_clears_highlight_and_shows_status(self):
        output = self.plugin("aerospace.sh", 'aerospace() { return 1; }', "unset FOCUSED_WORKSPACE")
        self.assertIn("<label=Waiting for AeroSpace>", output)
        self.assertEqual(output.count("<background.drawing=off>"), 7)
        self.assertNotIn("<background.drawing=on>", output)

    def test_service_mode_is_visible(self):
        output = self.plugin("aerospace.sh", 'aerospace() { printf service; }', "FOCUSED_WORKSPACE=2")
        self.assertIn("<aerospace_status><drawing=on><label=SERVICE · Esc to exit>", output)
        self.assertIn("<space.2><background.drawing=on>", output)

    def test_bar_builds_seven_buttons_before_aerospace_is_ready(self):
        script = ROOT / "sketchybar/sketchybarrc"
        output = self.shell(f'''aerospace() {{ return 1; }}
sketchybar() {{ printf '<%s>' "$@"; }}
CONFIG_DIR="$TEST_USER_DIR/.config/sketchybar"
source {shlex.quote(str(script))}
''').stdout
        for sid in range(1, 8):
            self.assertIn(f"<--add><item><space.{sid}><left>", output)
        self.assertIn("<update_freq=5>", output)
        self.assertIn("<aerospace_mode_change>", output)
        self.assertIn("<system_woke>", output)

    def test_running_registered_service_is_not_restarted(self):
        self.shell('''BREW=brew_stub
brew_stub() { printf '[{"running":true,"registered":true}]'; }
pkill() { printf unexpected > "$TEST_LOG"; }
ensure_bar_service
''')
        self.assertFalse((self.base / "calls").exists())

    def bar_fixture(self, missing=None, wrong=None, mode="main", status=True):
        for sid in range(1, 8):
            value = {} if sid == missing else {
                "label": {"value": str(sid)},
                "geometry": {"drawing": "on", "background": {
                    "drawing": "on" if sid == (wrong or 7) else "off"}}}
            (self.stage / f"space.{sid}").write_text(json.dumps(value))
        value = {"geometry": {"drawing": "off" if mode == "main" else "on"},
                 "label": {"value": mode.upper() + " · Esc to exit"}} if status else {}
        (self.stage / "aerospace_status").write_text(json.dumps(value))
        return f'''aerospace() {{ if [ "$1" = list-modes ]; then printf {mode}; else printf 7; fi; }}
sketchybar() {{ cat "$WORK_DIR/$2"; }}
check_bar_state
'''

    def test_health_rejects_missing_button_despite_responding_bar(self):
        result = self.shell(self.bar_fixture(missing=7), success=False)
        self.assertIn("Workspace button 7", result.stderr)

    def test_health_rejects_stale_selection(self):
        self.shell(self.bar_fixture(wrong=2), success=False)

    def test_health_requires_mode_indicator(self):
        self.shell(self.bar_fixture(mode="service", status=False), success=False)
        self.shell(self.bar_fixture(mode="service"))
        self.shell(self.bar_fixture())

    def preferences_stub(self, initial):
        state = self.base / "preferences.json"
        state.write_text(json.dumps(initial))
        mock = self.base / "mock_defaults.py"
        mock.write_text('''import json, os, sys
from pathlib import Path
p = Path(os.environ["TEST_PREFS"])
s = json.loads(p.read_text())
a = sys.argv[1:]
k = a[1] + "/" + a[2]
if a[0] == "read":
    if k not in s: sys.exit(1)
    print(s[k])
else:
    if a[0] == "write":
        if a[4] not in ("true", "false"): sys.exit(2)
        s[k] = int(a[4] == "true")
    elif a[0] == "delete": s.pop(k, None)
    else: sys.exit(99)
    p.write_text(json.dumps(s))
''')
        self.env["TEST_PREFS"] = str(state)
        return f'''defaults() {{ python3 {shlex.quote(str(mock))} "$@"; }}
killall() {{ printf 'restart %s\\n' "$*" >> "$TEST_LOG"; }}
export -f defaults killall
''', state

    def test_preferences_are_backed_up_applied_repeatable_and_restorable(self):
        original = {"com.apple.dock/expose-group-apps": 0,
                    "com.apple.WindowManager/EnableStandardClickToShowDesktop": 1}
        stub, state = self.preferences_stub(original)
        self.shell(stub + "SETTINGS_MODE=apply; prepare_settings; apply_settings; check_settings")
        values = json.loads(state.read_text())
        self.assertEqual(values["com.apple.dock/expose-group-apps"], 1)
        self.assertEqual(values["com.apple.WindowManager/EnableStandardClickToShowDesktop"], 0)
        self.assertEqual(values["com.apple.WindowManager/EnableTilingByEdgeDrag"], 0)
        self.assertFalse((self.base / "calls").exists())  # --no-start suppresses restarts
        self.shell(stub + "SETTINGS_MODE=apply; prepare_settings; apply_settings")
        backups = list(self.user_dir.glob(".config/tiling/*/restore.sh"))
        self.assertEqual(len(backups), 1)
        self.shell(stub + "/bin/bash " + shlex.quote(str(backups[0])))
        self.assertEqual(json.loads(state.read_text()), original)

    def test_preference_check_is_read_only_and_rejects_unset(self):
        stub, state = self.preferences_stub({})
        self.shell(stub + "check_settings", success=False)
        self.assertEqual(json.loads(state.read_text()), {})

    def test_declining_preferences_stops_before_configs_change(self):
        stub, state = self.preferences_stub({})
        self.shell(stub + "SETTINGS_MODE=ask; confirm() { return 1; }; prepare_settings; install_configs", success=False)
        self.assertFalse((self.user_dir / ".aerospace.toml").exists())
        self.assertEqual(json.loads(state.read_text()), {})

    def test_unexpected_preference_type_aborts_before_any_write(self):
        initial = {"com.apple.dock/expose-group-apps": "unexpected"}
        stub, state = self.preferences_stub(initial)
        self.shell(stub + "SETTINGS_NEEDED=1; apply_settings", success=False)
        self.assertEqual(json.loads(state.read_text()), initial)


if __name__ == "__main__":
    unittest.main(verbosity=2)
