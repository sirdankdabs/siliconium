#!/usr/bin/env python3
"""Siliconium: routes Steam's own starts of the given apps through silrelay.exe
(Steam's launch options: "<relay> %command%"), so a game that opens another
part from its menu (steam://run/<app>) gets that part started by Siliconium.
Launch options the player set are kept after %command%; an app whose options
already use %command% in another way is left alone. Run with Steam closed:
Steam rewrites localconfig.vdf when it exits.

    steam-launch-options.py <Steam folder> <relay command> <app id>...
"""
import glob
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location(
    'overlay', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'steam-overlay-off.py'))
vdf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vdf)


def main():
    steam, relay, apps = sys.argv[1], sys.argv[2], sys.argv[3:]
    template = relay + ' %command%'
    for path in glob.glob(os.path.join(steam, 'userdata', '*', 'config', 'localconfig.vdf')):
        with open(path, encoding='utf-8', errors='surrogateescape') as f:
            data = vdf.parse(f.read())
        store = vdf.child(data, 'UserLocalConfigStore')
        steam_apps = vdf.child(vdf.child(vdf.child(vdf.child(store, 'Software'), 'Valve'), 'Steam'), 'apps')
        changed = False
        for app in apps:
            block = vdf.child(steam_apps, app)
            old = next((i[1] for i in block if i[0].lower() == 'launchoptions' and not isinstance(i[1], list)), '')
            if relay in old:
                continue
            if '%command%' in old:
                print('steam-launch-options: app %s keeps its own launch options' % app, file=sys.stderr)
                continue
            changed |= vdf.setval(block, 'LaunchOptions', (template + ' ' + old.strip()).strip())
        if changed:
            tmp = path + '.sil-tmp'
            with open(tmp, 'w', encoding='utf-8', errors='surrogateescape') as f:
                f.write(vdf.dump(data))
            os.replace(tmp, path)


if __name__ == '__main__':
    main()
