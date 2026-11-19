"""Call Ezz's version methods directly through Wine's MSHTML bridge."""

import hashlib
import os
import stat
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile


# v3.0.0 from GitHub Releases and from Ezz's stable updater.
SUPPORTED_LAUNCHERS = {
    "e6c49cc3ecb145a05f92bd1051ebcafd9b201cf8c522b26308cce18156491a62",
    "16e8de49c3443a08ae46268baaff79442ad8f69c74d3d47673315ce5d9aedcef",
}


def patch_version_selector(path: Path) -> bool:
    try:
        source = path.read_bytes()
    except FileNotFoundError:
        return False

    # Reading a COM method as a property under Wine can invoke it without
    # arguments. In particular, setSelectedVersion then returns an empty value.
    replacements = (
        (b"if (ex && ex.setSelectedVersion) {", b"if (ex) {"),
        (
            b"    var sv =\n"
            b"      getExternal() &&\n"
            b"      getExternal().getSelectedVersion &&\n"
            b"      getExternal().getSelectedVersion();",
            b"    var ex = getExternal();\n"
            b"    var sv = ex && ex.getSelectedVersion(); // Siliconium Wine compatibility",
        ),
    )
    if replacements[1][1] in source:
        return True
    if any(source.count(before) != 1 for before, _ in replacements):
        return False

    for before, after in replacements:
        source = source.replace(before, after)
    with NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        pending = Path(temporary.name)
        try:
            temporary.write(source)
            temporary.close()
            pending.chmod(stat.S_IMODE(path.stat().st_mode))
            os.replace(pending, path)
        finally:
            pending.unlink(missing_ok=True)
    return True


if __name__ == "__main__":
    launcher, script = map(Path, sys.argv[1:])
    supported = hashlib.sha256(launcher.read_bytes()).hexdigest() in SUPPORTED_LAUNCHERS
    sys.exit(0 if supported and patch_version_selector(script) else 1)
