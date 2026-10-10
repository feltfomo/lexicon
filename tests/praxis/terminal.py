import errno
import os
import pty
import select
import signal
import sys
import termios
import time


def child(mode):
    assert os.read(0, 1) == b"", "ordinary steps must keep stdin closed"
    with open("/dev/tty", "r+b", buffering=0) as tty:
        tty.write(f"foreground:{os.tcgetpgrp(tty.fileno()) == os.getpgrp()}\n".encode())
        settings = termios.tcgetattr(tty)
        settings[3] &= ~(termios.ECHO | termios.ECHONL)
        termios.tcsetattr(tty, termios.TCSANOW, settings)
        if mode == "failure":
            raise SystemExit(23)
        if mode == "wait":
            tty.write(b"waiting with echo disabled\n")
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            time.sleep(60)
        else:
            tty.write(b"password:")
            assert tty.readline() == b"test-password\n"
            tty.write(b"password accepted\n")


class Session:
    def __init__(self, runner, manifest, command):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.pop("CI", None)
            os.execv(runner, [runner, "--manifest", manifest, "run", command])
        self.saved = termios.tcgetattr(self.fd)
        self.output = bytearray()
        self.status = None
        self.deadline = time.monotonic() + 10

    def read(self):
        assert time.monotonic() < self.deadline, bytes(self.output)
        if select.select([self.fd], [], [], 0.05)[0]:
            try:
                self.output.extend(os.read(self.fd, 4096))
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
        if self.status is None:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                self.status = os.waitstatus_to_exitcode(status)

    def expect(self, text):
        while text not in self.output:
            self.read()
            assert self.status is None or text in self.output, bytes(self.output)

    def send(self, text):
        os.write(self.fd, text)

    def finish(self, expected):
        while self.status is None:
            self.read()
        assert self.status == expected, (self.status, bytes(self.output))
        assert termios.tcgetattr(self.fd) == self.saved, "terminal settings were not restored"
        assert b"test-password" not in self.output, "password was echoed"

    def close(self):
        if self.status is None:
            os.kill(self.pid, signal.SIGTERM)
            try:
                while self.status is None:
                    self.read()
            finally:
                if self.status is None:
                    foreground = os.tcgetpgrp(self.fd)
                    if foreground > 0:
                        os.killpg(foreground, signal.SIGKILL)
                    os.kill(self.pid, signal.SIGKILL)
                    os.waitpid(self.pid, 0)
        os.close(self.fd)


def check(runner, manifest, command, expected, interaction=None):
    session = Session(runner, manifest, command)
    try:
        if interaction:
            interaction(session)
        session.finish(expected)
    finally:
        session.close()


def password(session):
    session.expect(b"Start terminal child?")
    session.send(b"y\n")
    session.expect(b"password:")
    assert b"foreground:True" in session.output, bytes(session.output)
    assert not termios.tcgetattr(session.fd)[3] & termios.ECHO
    session.send(b"test-password\n")
    session.expect(b"Terminal returned?")
    assert os.tcgetpgrp(session.fd) == session.pid, "terminal ownership was not returned"
    assert termios.tcgetattr(session.fd) == session.saved
    session.send(b"y\n")


def cancel(session):
    session.expect(b"waiting with echo disabled")
    session.send(b"\x03")


if sys.argv[1] == "child":
    child(sys.argv[2])
else:
    runner, manifest = sys.argv[1:]
    check(runner, manifest, "terminal-password", 0, password)
    check(runner, manifest, "terminal-failure", 23)
    check(runner, manifest, "terminal-timeout", 124)
    check(runner, manifest, "terminal-cancel", 130, cancel)
    check(runner, manifest, "terminal-spawn-failure", 127)
    print("terminal checks passed: password input, failure, timeout, cancellation and spawn failure")
