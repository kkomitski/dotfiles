"""Check independent sessions and pane behavior on a disposable tmux server."""
import fcntl
import termios
import shutil
import os
from pathlib import Path
import pty
import subprocess
import tempfile
import time
import unittest


class SessionTests(unittest.TestCase):
    def test_launchers_create_independent_sessions(self):
        launcher = Path(__file__).resolve().parents[1] / 'bin' / 'WSL Terminal'
        with tempfile.TemporaryDirectory(prefix='wsl-terminal-tmux-') as temporary:
            env = dict(os.environ, TMUX_TMPDIR=temporary, TERM='xterm-256color', WT_SESSION='portable-test')
            env.pop('TMUX', None)
            clients = []
            def tmux(*args):
                return subprocess.check_output(['tmux', *args], env=env, stderr=subprocess.DEVNULL, text=True).strip()
            try:
                # Load this checkout even if the user's ~/.tmux.conf is unrelated.
                subprocess.check_call(['tmux', '-f', str(launcher.parents[2] / '.tmux.conf'),
                    'start-server', ';', 'set-option', '-g', 'exit-empty', 'off'], env=env,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                for index in range(2):
                    master, slave = pty.openpty()
                    def control_terminal():
                        os.setsid()
                        fcntl.ioctl(0, termios.TIOCSCTTY, 0)
                    child = subprocess.Popen([str(launcher)], env=env, stdin=slave, stdout=slave, stderr=slave, preexec_fn=control_terminal)
                    os.close(slave)
                    clients.append((child, master))
                    until = time.monotonic() + 8
                    while True:
                        try:
                            sessions = tmux('list-sessions', '-F', '#{session_id}').splitlines()
                            if len(sessions) == index + 1:
                                break
                        except subprocess.CalledProcessError:
                            pass
                        if time.monotonic() > until:
                            os.set_blocking(master, False)
                            try:
                                output = os.read(master, 16384).decode(errors='replace')
                            except (BlockingIOError, OSError):
                                output = ''
                            self.fail('Launcher did not create a new session: '+output)
                        time.sleep(.05)
                self.assertEqual(len(set(sessions)), 2)
                self.assertIn('xterm-256color:RGB', tmux('show-options', '-s', '-v', 'terminal-features'))
                self.assertEqual(tmux('show-options', '-g', '-v', 'default-shell'), str(Path.home() / '.local/bin/zsh') if (Path.home() / '.local/bin/zsh').exists() else shutil.which('zsh'))
                tmux('split-window', '-h', '-d', '-t', sessions[0])
                self.assertEqual(tmux('display-message', '-p', '-t', sessions[0], '#{window_panes}'), '2')
                self.assertEqual(tmux('display-message', '-p', '-t', sessions[1], '#{window_panes}'), '1')
            finally:
                try:
                    tmux('kill-server')
                except subprocess.CalledProcessError:
                    pass
                for child, master in clients:
                    if child.poll() is None:
                        child.terminate()
                    child.wait(timeout=5)
                    os.close(master)
