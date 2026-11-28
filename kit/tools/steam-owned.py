"""Read owned Steam AppIDs from Steam's local appcache/packageinfo.vdf.

Steam populates appcache/packageinfo.vdf with the package definitions for the
signed-in account's licenses (including Family Sharing). Reading it locally
requires no Steam Web API key, works for private profiles and offline, and
never reads account credentials or SteamIDs.

Usage: steam-owned.py <steam_dir> [appid ...]
Output:
  First line: "known" when packageinfo.vdf has user packages beyond pkg 0,
              "unknown" otherwise (not signed in / cache not synced yet).
  Remaining lines (when "known"): owned AppIDs (filtered to argv[2:] if given).
"""

import os
import struct
import sys


def parse_bvdf(buf: bytes, off: int):
    out = {}
    n = len(buf)
    while off < n:
        t = buf[off]
        off += 1
        if t == 0x08:
            break
        end = buf.index(0, off)
        key = buf[off:end].decode("utf-8", "ignore")
        off = end + 1
        if t == 0x00:
            val, off = parse_bvdf(buf, off)
            out[key] = val
        elif t == 0x01:
            end = buf.index(0, off)
            val = buf[off:end].decode("utf-8", "ignore")
            off = end + 1
            out[key] = val
        elif t == 0x02:
            val = struct.unpack_from("<I", buf, off)[0]
            off += 4
            out[key] = val
        elif t == 0x03:
            val = struct.unpack_from("<f", buf, off)[0]
            off += 4
            out[key] = val
        elif t == 0x07:
            val = struct.unpack_from("<Q", buf, off)[0]
            off += 8
            out[key] = val
        else:
            raise ValueError(f"unsupported binary VDF type 0x{t:02x}")
    return out, off


def main() -> int:
    if len(sys.argv) < 2:
        print("unknown")
        return 0
    path = os.path.join(sys.argv[1], "appcache", "packageinfo.vdf")
    wanted = {int(a) for a in sys.argv[2:] if a.isdigit()}
    if not os.path.isfile(path):
        print("unknown")
        return 0
    try:
        data = open(path, "rb").read()
        if len(data) < 12:
            print("unknown")
            return 0
        magic, _universe = struct.unpack_from("<II", data, 0)
        if magic not in (0x06565527, 0x06565528):
            print("unknown")
            return 0
        pos = 8
        user_packages = 0
        owned = set()
        while pos + 4 <= len(data):
            pkgid = struct.unpack_from("<I", data, pos)[0]
            pos += 4
            if pkgid == 0xFFFFFFFF:
                break
            # 20-byte SHA-1 + 4-byte change number (+ 8-byte PICS token in v28)
            pos += 24 + (8 if magic >= 0x06565528 else 0)
            tree, pos = parse_bvdf(data, pos)
            if pkgid != 0:
                user_packages += 1
            inner = next(iter(tree.values())) if tree else {}
            apps = inner.get("appids") if isinstance(inner, dict) else None
            if isinstance(apps, dict):
                for aid in apps.values():
                    if isinstance(aid, int):
                        owned.add(aid)
    except Exception:
        print("unknown")
        return 0

    if user_packages == 0:
        print("unknown")
        return 0

    print("known")
    result = sorted(owned & wanted) if wanted else sorted(owned)
    for aid in result:
        print(aid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
