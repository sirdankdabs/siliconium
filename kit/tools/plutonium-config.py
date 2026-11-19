"""Link a Siliconium game folder in Plutonium's launcher configuration."""

import json
import os
import sys
import tempfile


def main():
    action, path, *args = sys.argv[1:]
    try:
        with open(path, encoding="utf-8") as file:
            config = json.load(file)
        if not isinstance(config, dict):
            return 1

        token = config.get("token")
        if not isinstance(token, str) or not token.strip():
            return 1
        if action == "signed-in":
            return 0

        game, folder, *mode = args
        key = game + "Path"
        # The scripts pass the Windows path (kit/tools/winpath.sh maps folders
        # Windows cannot name to a drive letter); a Mac path still works.
        if folder.startswith("/"):
            windows_path = "Z:" + folder.replace("/", "\\")
        else:
            windows_path = folder
        updates = {key: windows_path}
        if mode:
            updates["lastGame"] = mode[0]
        if all(config.get(key) == value for key, value in updates.items()):
            return 0
        config.update(updates)

        # Replace the config only after writing it completely. mkstemp keeps
        # the saved session private and places the temporary file on the same volume.
        fd, temporary = tempfile.mkstemp(prefix=".sil-config-", dir=os.path.dirname(path))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as file:
                json.dump(config, file, ensure_ascii=False, separators=(",", ":"))
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    except (OSError, ValueError):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
