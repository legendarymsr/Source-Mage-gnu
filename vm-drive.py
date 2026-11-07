#!/usr/bin/env python3
# vm-drive.py — a tiny "expect" for a QEMU serial console. Used by setup-vm.sh; standard library only.
#
#   vm-drive.py SOCK LOG wait  REGEX [TIMEOUT]       wait until REGEX shows up in the console output
#   vm-drive.py SOCK LOG send  TEXT                   type TEXT (\n and \x03 escapes allowed)
#   vm-drive.py SOCK LOG run   COMMAND [TIMEOUT]      run a shell command, stream its output, exit with its status
#   vm-drive.py SOCK LOG put   FILE DEST              copy a (small) file into the guest, base64 over the console
#   vm-drive.py SOCK LOG secret VAR...                export each VAR in the guest shell with the value of the same
#                                                     variable in OUR environment; typed into `read -rs`, so it is
#                                                     never echoed (not in LOG) and never on a command line (not in ps)
#
# SOCK is QEMU's  -chardev socket,...,path=SOCK,server=on,logfile=LOG  serial socket. Output is read from LOG (so
# nothing is lost between calls), input is written to SOCK. Exit codes: 0 ok, 124 timeout, 125 VM exited (set VM_PID), otherwise the command's.

import base64, os, re, secrets, socket, sys, time

ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][A-Za-z0-9]|\x1b[=>]|\r")


def log_size(path):
    try:
        return os.path.getsize(path)
    except OSError:
        return 0


def send(sock_path, data, pause=0.15):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    s.sendall(data)
    time.sleep(pause)
    s.close()


def pump(log_path, offset, pattern, timeout, echo=True):
    """Read new console output from offset until pattern matches. Returns (match|None, new_offset)."""
    rx = re.compile(pattern.encode() if isinstance(pattern, str) else pattern)
    deadline, buf = time.time() + timeout, b""
    while time.time() < deadline:
        size = log_size(log_path)
        if size > offset:
            with open(log_path, "rb") as f:
                f.seek(offset)
                chunk = f.read(size - offset)
            offset = size
            clean = ANSI.sub(b"", chunk)
            if echo and clean:
                sys.stdout.buffer.write(clean)
                sys.stdout.buffer.flush()
            buf = (buf + clean)[-65536:]
            m = rx.search(buf)
            if m:
                return m, offset
        else:
            pid = os.environ.get("VM_PID")           # QEMU gone: stop waiting
            if pid and not os.path.exists("/proc/" + pid):
                sys.stderr.write("\nvm-drive: the VM exited\n")
                sys.exit(125)
            time.sleep(0.3)
    return None, offset


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    sock, log, action, *args = sys.argv[1:]
    if action == "wait":
        m, _ = pump(log, 0 if os.environ.get("FROM_START") else log_size(log), args[0],
                    float(args[1]) if len(args) > 1 else 600)
        sys.exit(0 if m else 124)
    if action == "send":
        send(sock, args[0].encode().decode("unicode_escape").encode())
        return
    if action == "run":
        cmd, timeout = args[0], float(args[1]) if len(args) > 1 else 3600
        tag = secrets.token_hex(4)
        # the marker is built with an empty "" so the terminal's echo of this very line does not contain it
        line = '%s\necho __SM""DONE_%s__$?__\n' % (cmd, tag)
        off = log_size(log)
        send(sock, line.encode())
        m, _ = pump(log, off, r"__SMDONE_%s__(\d+)__" % tag, timeout)
        sys.stdout.write("\n")
        sys.exit(int(m.group(1)) if m else 124)
    if action == "put":
        # base64 in short lines (the console is a slow, small-buffered serial line), then verify with sha256
        src, dest = args
        raw = open(src, "rb").read()
        import hashlib
        want = hashlib.sha256(raw).hexdigest()
        data = base64.b64encode(raw).decode()
        tag = secrets.token_hex(4)
        off = log_size(log)
        send(sock, b"stty -echo; cat > /tmp/put.b64 <<'PUT_EOF'\n")
        for i in range(0, len(data), 76):
            send(sock, (data[i:i + 76] + "\n").encode(), 0.02)
        send(sock, ('PUT_EOF\nstty echo; base64 -d /tmp/put.b64 > %s && [ "$(sha256sum < %s | cut -d" " -f1)" = %s ]; '
                    'echo __SM""DONE_%s__$?__\n' % (dest, dest, want, tag)).encode())
        m, _ = pump(log, off, r"__SMDONE_%s__(\d+)__" % tag, 120, echo=False)
        sys.exit(int(m.group(1)) if m else 124)
    if action == "secret":
        for var in args:
            if not re.fullmatch(r"[A-Z_][A-Z0-9_]*", var) or var not in os.environ:
                sys.exit("secret: %s is not a set variable name" % var)
            val = os.environ[var]
            if "\n" in val or "\r" in val:
                sys.exit("secret: %s contains a newline" % var)
            tag = secrets.token_hex(4)
            off = log_size(log)
            send(sock, ("IFS= read -rs %s && export %s; echo __SM\"\"DONE_%s__$?__\n" % (var, var, tag)).encode(), 1.0)
            send(sock, (val + "\n").encode())
            m, _ = pump(log, off, r"__SMDONE_%s__(\d+)__" % tag, 30, echo=False)
            if not m or m.group(1) != "0":
                sys.exit(124 if not m else int(m.group(1)))
        return
    sys.exit("unknown action: " + action)


if __name__ == "__main__":
    main()
