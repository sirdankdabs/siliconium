#!/usr/bin/env python3
"""bo2-hwprofile.py <hardware*.chp> <WIDTHxHEIGHT>: put that resolution in a
Black Ops II hardware profile.

Black Ops II keeps its display settings in a binary hardware profile
(players/hardware.chp, Plutonium's hardware_mp.chp / hardware_zm.chp) and
starts with the resolution saved there, not with r_mode from its .cfg: the
.cfg's value only applies "upon restarting" the renderer. So after the Mac's
resolution changed, every start opened at the previous game's resolution (a
1920x1080 desktop at 2560x1440, then the other way round, 2026-11-24) and
switched the display's mode while it ran.

The profile is a bit stream (least significant bit first, not byte aligned)
in which the resolution is a 16-byte text field, e.g. "1920x1080" and zeros
(found at bit 774 in every profile seen: ours from an Apple GPU, Plutonium's
multiplayer and Zombies ones). The field is looked up, not assumed: exactly
one "<digits>x<digits>" text padded with zeros to 16 bytes must be found,
else the file is left as it is. Only those 16 bytes change; the file is
replaced atomically. Prints what it did; exit 0 when the file holds the
resolution afterwards (or was left alone on purpose), 1 when it could not.
"""
import os
import re
import sys
import tempfile

FIELD = 16
PATTERN = re.compile(rb"(?=([1-9][0-9]{2,3}x[1-9][0-9]{2,3})\x00)")


def bit(data, i):
    return (data[i >> 3] >> (i & 7)) & 1


def read_bytes(data, start, count):
    out = bytearray()
    for n in range(count):
        v = 0
        for j in range(8):
            v |= bit(data, start + 8 * n + j) << j
        out.append(v)
    return bytes(out)


def find_field(data):
    found = []
    for k in range(8):
        stream = read_bytes(data, k, (len(data) * 8 - k) // 8)
        for m in PATTERN.finditer(stream):
            start, text = m.start(1), m.group(1)
            field = stream[start:start + FIELD]
            if len(field) == FIELD and field == text + b"\x00" * (FIELD - len(text)):
                found.append((start * 8 + k, text))
    return found


def main():
    if len(sys.argv) != 3 or not re.fullmatch(r"[1-9][0-9]{2,3}x[1-9][0-9]{2,3}", sys.argv[2]):
        print("usage: bo2-hwprofile.py <hardware.chp> <WIDTHxHEIGHT>", file=sys.stderr)
        return 2
    path, want = sys.argv[1], sys.argv[2].encode()
    try:
        data = bytearray(open(path, "rb").read())
    except OSError as e:
        print(f"bo2-hwprofile: {path}: {e.strerror}")
        return 1
    found = find_field(data)
    if len(found) != 1:
        print(f"bo2-hwprofile: {os.path.basename(path)}: resolution field not found "
              f"({len(found)} candidates), left as it is")
        return 1
    start, have = found[0]
    if have == want:
        return 0
    new = want + b"\x00" * (FIELD - len(want))
    for n, value in enumerate(new):
        for j in range(8):
            i = start + 8 * n + j
            if (value >> j) & 1:
                data[i >> 3] |= 1 << (i & 7)
            else:
                data[i >> 3] &= ~(1 << (i & 7)) & 0xFF
    if find_field(data) != [(start, want)]:
        print(f"bo2-hwprofile: {os.path.basename(path)}: check after the change failed, left as it is")
        return 1
    folder = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".chp.", dir=folder)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, os.stat(path).st_mode & 0o777)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        print(f"bo2-hwprofile: {os.path.basename(path)}: could not write")
        return 1
    print(f"bo2-hwprofile: {os.path.basename(path)}: {have.decode()} -> {want.decode()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
