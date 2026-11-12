#!/usr/bin/env python3
"""Exercise real ZLE editing and tty signals in disposable pseudo-terminals."""
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import struct
import subprocess
import tempfile
import termios
import time
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'zsh' / 'WSL Terminal.zsh'


class NavigationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='wsl-terminal-zle-')
        self.root = Path(self.tmp.name)
        self.buffer = self.root / 'buffer'
        self.state = self.root / 'state'
        self.clipboard = self.root / 'clipboard'
        self.ready = self.root / 'ready'
        mock = self.root / 'pbcopy'
        mock.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nPath(os.environ["WSL_TEST_CLIPBOARD"]).write_bytes(sys.stdin.buffer.read())\n')
        mock.chmod(0o755)
        env = os.environ.copy()
        env['PATH'] = str(self.root) + ':' + env['PATH']
        env['WSL_TEST_CLIPBOARD'] = str(self.clipboard)
        env['TERM'] = 'xterm-256color'
        env['LC_ALL'] = 'C.UTF-8'
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 100, 0, 0))

        def control_terminal():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.proc = subprocess.Popen([os.environ.get('ZSH_BIN', shutil.which('zsh')), '-dfi'], stdin=slave, stdout=slave, stderr=slave, env=env, preexec_fn=control_terminal)
        os.close(slave)
        # Existing user-local Zsh builds may need module_path from .zshenv.
        setup = (
            '[[ ! -r "$HOME/.zshenv" ]] || source "$HOME/.zshenv"; '
            'export PATH=' + shlex.quote(str(self.root)) + ':"$PATH"; bindkey -e; '
            'source ' + shlex.quote(str(MODULE)) + '; PROMPT="__WSL_READY__> "; '
            'dump_buffer() { print -rn -- "$BUFFER" > ' + shlex.quote(str(self.buffer)) + '; '
            'print -r -- "$MARK $CURSOR $REGION_ACTIVE" > ' + shlex.quote(str(self.state)) + '; '
            'BUFFER=""; REGION_ACTIVE=0; zle accept-line; }; '
            'zle -N dump_buffer; bindkey "^]" dump_buffer; touch ' + shlex.quote(str(self.ready)) + '\n'
        )
        self.send(setup)
        self.wait_file(self.ready)
        self.read_for(.1)

    def tearDown(self):
        self.proc.kill()
        self.proc.wait(timeout=3)
        os.close(self.master)
        self.tmp.cleanup()

    def send(self, text):
        os.write(self.master, text.encode())

    def read_for(self, seconds):
        result = b''
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            if select.select([self.master], [], [], .01)[0]:
                result += os.read(self.master, 65536)
        return result

    def wait_file(self, path):
        until = time.monotonic() + 5
        output = b''
        while not path.exists() and time.monotonic() < until:
            output += self.read_for(.02)
        self.assertTrue(path.exists(), output[-2000:].decode(errors='replace'))

    def edit(self, keys, text='alpha beta gamma'):
        self.send('\x1b[200~' + text + '\x1b[201~' + keys + '\x1d')
        self.wait_file(self.state)
        actual = self.buffer.read_text()
        mark, cursor, active = map(int, self.state.read_text().split())
        return actual, actual[min(mark, cursor):max(mark, cursor)], active

    def test_highlighting_after_full_startup(self):
        ready = self.root / 'full-startup-ready'
        colors = self.root / 'syntax-colors'
        probe = (
            'source "$HOME/.zshrc"; '
            'probe_colors() { '
            'BUFFER="__dotfiles_unknown_command__"; CURSOR=${#BUFFER}; _zsh_highlight; '
            'print -r -- "invalid:${(j:;:)region_highlight}" > ' + shlex.quote(str(colors)) + '; '
            'BUFFER="echo valid"; CURSOR=${#BUFFER}; _zsh_highlight; '
            'print -r -- "valid:${(j:;:)region_highlight}" >> ' + shlex.quote(str(colors)) + '; '
            'print -r -- "autosuggest:${+functions[_zsh_autosuggest_start]}" >> ' + shlex.quote(str(colors)) + '; '
            'BUFFER=""; zle accept-line; }; '
            'zle -N probe_colors; bindkey "^]" probe_colors; touch ' + shlex.quote(str(ready)) + '\n'
        )
        self.send(probe)
        self.wait_file(ready)
        self.read_for(.1)
        self.send('\x1d')
        self.wait_file(colors)
        output = colors.read_text()
        self.assertRegex(output, r'invalid:.*fg=red')
        self.assertRegex(output, r'valid:.*fg=green')
        self.assertIn('autosuggest:1', output)

    def test_line_selection_left(self):
        self.assertEqual(self.edit('\x1b[1;2H'), ('alpha beta gamma', 'alpha beta gamma', 1))

    def test_line_selection_right(self):
        self.assertEqual(self.edit('\x1b[H\x1b[1;2F'), ('alpha beta gamma', 'alpha beta gamma', 1))

    def test_word_selection(self):
        self.assertEqual(self.edit('\x1b[1;6D'), ('alpha beta gamma', 'gamma', 1))

    def test_expansion_and_shrink(self):
        self.assertEqual(self.edit('\x1b[1;6D\x1b[1;6D\x1b[1;6C'), ('alpha beta gamma', ' gamma', 1))

    def test_type_over_selection(self):
        self.assertEqual(self.edit('\x1b[1;6DX')[0], 'alpha beta X')

    def test_paste_over_selection(self):
        self.assertEqual(self.edit('\x1b[1;6D\x1b[200~XYZ\x1b[201~')[0], 'alpha beta XYZ')

    def test_backspace_selection(self):
        self.assertEqual(self.edit('\x1b[1;6D\x7f')[0], 'alpha beta ')

    def test_deletion_returns_success(self):
        status = self.root / 'status'
        self.send('audit_delete() { _wsl_edit backward-delete-char; local result=$?; print -r -- "$result" > ' + shlex.quote(str(status)) + '; }; zle -N _wsl_backspace audit_delete\n')
        self.read_for(.1)
        self.edit('\x1b[1;6D\x7f')
        self.assertEqual(status.read_text().strip(), '0')

    def test_word_and_line_deletion(self):
        self.assertEqual(self.edit('\x1b[1;5D\x15')[0], 'gamma')

    def test_option_backspace_transport(self):
        self.assertEqual(self.edit('\x1b\x7f')[0], 'alpha beta ')

    def test_copy_unicode_selection(self):
        text = 'hello café 🐧\nsecond line'
        self.assertEqual(self.edit('\x01\x03', text)[0], text)
        self.assertEqual(self.clipboard.read_text(), text)

    def test_cut_selection(self):
        self.assertEqual(self.edit('\x1b[1;6D\x18')[0], 'alpha beta ')
        self.assertEqual(self.clipboard.read_text(), 'gamma')

    def test_multiline_document_selection(self):
        text = 'first line\nsecond line'
        self.assertEqual(self.edit('\x1b[1;6H', text), (text, text, 1))

    def test_movement_cancels_selection(self):
        self.assertEqual(self.edit('\x1b[1;6D\x1b[H')[2], 0)

    def test_ctrl_s_does_not_freeze_output(self):
        self.assertFalse(termios.tcgetattr(self.master)[0] & termios.IXON)
        self.send('\x13FLOWCHECK')
        self.assertIn(b'FLOWCHECK', self.read_for(.2))

    def test_ctrl_c_cancels_unselected_input(self):
        self.send('unexecuted text\x03')
        self.read_for(.2)
        self.send('\x1d')
        self.wait_file(self.state)
        self.assertEqual(self.buffer.read_text(), '')

    def test_running_command_ctrl_c_still_interrupts(self):
        self.send('/bin/sleep 30\n')
        self.read_for(.1)
        self.assertEqual(termios.tcgetattr(self.master)[6][termios.VINTR], b'\x03')
        self.send('\x03')
        self.assertIn(b'__WSL_READY__>', self.read_for(.3))
        self.assertIsNone(self.proc.poll())


if __name__ == '__main__':
    unittest.main(verbosity=2)
