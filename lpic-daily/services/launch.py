#!/usr/bin/env python3
"""Launch LPIC Daily in the terminal configured by Serpantinum.

No shell evaluation: the trusted launcher setting is split into argv.
"""
import argparse
import shlex
import shutil
import subprocess
import sys


def terminal_argv(configured: str) -> list[str]:
    try:
        parts = shlex.split(configured)
    except ValueError:
        parts = []
    if parts and shutil.which(parts[0]):
        return parts
    for candidate in (
        ["kitty", "-e"], ["foot", "-e"], ["alacritty", "-e"],
        ["wezterm", "start", "--"], ["konsole", "-e"],
        ["gnome-terminal", "--"], ["xfce4-terminal", "-x"],
        ["xdg-terminal-exec"],
    ):
        if shutil.which(candidate[0]):
            return candidate
    raise RuntimeError("Aucun terminal compatible trouvé")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("next", "dashboard"))
    parser.add_argument("--terminal", default="kitty -e")
    args = parser.parse_args()

    binary = shutil.which("lpic")
    if binary is None:
        print("lpic introuvable dans PATH", file=sys.stderr)
        return 1
    command = [binary, "launch", "--next"] if args.action == "next" else [binary]
    try:
        subprocess.Popen(
            terminal_argv(args.terminal) + command,
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, RuntimeError) as exc:
        print(f"Impossible d'ouvrir LPIC Daily : {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
