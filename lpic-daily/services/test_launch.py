import importlib.util
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("lpic_launcher", Path(__file__).with_name("launch.py"))
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)


class TerminalSelectionTests(TestCase):
    @patch.object(launch.shutil, "which")
    def test_keeps_serpantinum_terminal(self, which):
        which.side_effect = lambda cmd: "/usr/bin/" + cmd if cmd == "kitty" else None
        self.assertEqual(launch.terminal_argv("kitty -e"), ["kitty", "-e"])

    @patch.object(launch.shutil, "which")
    def test_falls_back_without_shell(self, which):
        which.side_effect = lambda cmd: "/usr/bin/" + cmd if cmd == "foot" else None
        self.assertEqual(launch.terminal_argv("missing-terminal --bad"), ["foot", "-e"])

    @patch.object(launch.shutil, "which", return_value=None)
    def test_no_terminal_raises(self, which):
        with self.assertRaisesRegex(RuntimeError, "Aucun terminal"):
            launch.terminal_argv("")
