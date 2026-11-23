"""Siliconium: the games Battle.net's Agent knows (ProgramData/Battle.net/Agent/product.db).

product.db is a protocol buffer (Blizzard's "Database" message). Read with a
plain wire-format walker, no generated code:
  Database           1: ProductInstall (repeated)
  ProductInstall     1: uid ("viper" = Black Ops 4)  2: product code
                     3: UserSettings  4: CachedProductState
  UserSettings       1: install path ("C:/Program Files (x86)/…")
  CachedProductState 1: BaseProductState
  BaseProductState   1: installed  2: playable  3: update complete
                     7: installed version ("1.23.5.27458377"; empty while the
                        first download runs: the Agent's "local_version")

Prints one line per game:
  <uid>|<install path>|<installed 0/1>|<playable 0/1>|<installed version>
--dump <file> prints the whole tree (to check the fields above).
"""
import sys


def varint(b, i):
    n = s = 0
    while True:
        c = b[i]
        i += 1
        n |= (c & 0x7F) << s
        s += 7
        if c < 0x80:
            return n, i


def fields(b):
    """(number, wire type, value) of one message; raises on malformed data."""
    i = 0
    out = []
    while i < len(b):
        key, i = varint(b, i)
        num, wt = key >> 3, key & 7
        if wt == 0:
            v, i = varint(b, i)
        elif wt == 1:
            v, i = b[i:i + 8], i + 8
        elif wt == 2:
            n, i = varint(b, i)
            v, i = b[i:i + n], i + n
        elif wt == 5:
            v, i = b[i:i + 4], i + 4
        else:
            raise ValueError("wire type %d" % wt)
        if i > len(b) or num == 0:
            raise ValueError("truncated")
        out.append((num, wt, v))
    return out


def first(fs, num, wt):
    for n, w, v in fs:
        if n == num and w == wt:
            return v
    return None


def sub(fs, num):
    v = first(fs, num, 2)
    try:
        return fields(v) if v is not None else []
    except (ValueError, IndexError):
        return []


def text(v):
    return v.decode("utf-8", "replace") if isinstance(v, (bytes, bytearray)) else ""


def dump(b, depth=0):
    try:
        fs = fields(b)
    except (ValueError, IndexError):
        return False
    for n, w, v in fs:
        pad = "  " * depth
        if w == 2:
            if v and all(32 <= c < 127 for c in v):
                print("%s%d: %r" % (pad, n, v.decode()))
            else:
                print("%s%d: {" % (pad, n))
                if not dump(v, depth + 1):
                    print("%s  <%d bytes>" % (pad, len(v)))
                print("%s}" % pad)
        else:
            print("%s%d: %r" % (pad, n, v))
    return True


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--dump":
        with open(sys.argv[2], "rb") as f:
            dump(f.read())
        return
    with open(sys.argv[1], "rb") as f:
        db = fields(f.read())
    for n, w, v in db:
        if n != 1 or w != 2:
            continue
        try:
            p = fields(v)
        except (ValueError, IndexError):
            continue
        uid = text(first(p, 1, 2))
        path = text(first(sub(p, 3), 1, 2))
        base = sub(sub(p, 4), 1)
        installed = 1 if first(base, 1, 0) else 0
        playable = 1 if first(base, 2, 0) else 0
        version = text(first(base, 7, 2)).replace("|", "")
        if uid:
            print("%s|%s|%d|%d|%s" % (uid, path.replace("|", ""), installed, playable, version))


if __name__ == "__main__":
    main()
