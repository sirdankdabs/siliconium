#!/usr/bin/env python3
"""Siliconium: turns Steam's in-game overlay off in Steam's own settings
(userdata/<account>/config/localconfig.vdf): "EnableGameOverlay" "0" for the
account and "OverlayAppEnable" "0" for each app given. The overlay does not
draw under Wine. (Removing its DLLs made Steam reinstall itself at every
start, and an unsigned stand-in made Steam refuse to start games: AppError 49,
"Corrupt file signature".) Run with Steam closed: Steam rewrites the file
when it exits.

    steam-overlay-off.py <Steam folder> <app id>...
"""
import glob
import os
import sys


def parse(text):
    tokens, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in ' \t\r\n':
            i += 1
        elif c == '/' and text.startswith('//', i):
            i = text.find('\n', i)
            i = n if i < 0 else i
        elif c in '{}':
            tokens.append(c)
            i += 1
        elif c == '"':
            j, out = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == '\\' and j + 1 < n:
                    out.append(text[j:j + 2])
                    j += 2
                else:
                    out.append(text[j])
                    j += 1
            tokens.append(('s', ''.join(out)))
            i = j + 1
        else:
            j = i
            while j < n and text[j] not in ' \t\r\n{}"':
                j += 1
            tokens.append(('s', text[i:j]))
            i = j
    pos = 0

    def block():
        nonlocal pos
        items = []
        while pos < len(tokens):
            t = tokens[pos]
            if t == '}':
                pos += 1
                return items
            key = t[1]
            pos += 1
            if tokens[pos] == '{':
                pos += 1
                items.append([key, block()])
            else:
                items.append([key, tokens[pos][1]])
                pos += 1
        return items

    return block()


def dump(items, depth=0):
    out = []
    tab = '\t' * depth
    for key, value in items:
        if isinstance(value, list):
            out.append(f'{tab}"{key}"\n{tab}{{\n{dump(value, depth + 1)}{tab}}}\n')
        else:
            out.append(f'{tab}"{key}"\t\t"{value}"\n')
    return ''.join(out)


def child(items, key):
    for item in items:
        if item[0].lower() == key.lower() and isinstance(item[1], list):
            return item[1]
    new = [key, []]
    items.append(new)
    return new[1]


def setval(items, key, value):
    for item in items:
        if item[0].lower() == key.lower() and not isinstance(item[1], list):
            changed = item[1] != value
            item[1] = value
            return changed
    items.append([key, value])
    return True


def main():
    steam, apps = sys.argv[1], sys.argv[2:]
    for path in glob.glob(os.path.join(steam, 'userdata', '*', 'config', 'localconfig.vdf')):
        with open(path, encoding='utf-8', errors='surrogateescape') as f:
            data = parse(f.read())
        store = child(data, 'UserLocalConfigStore')
        changed = setval(child(store, 'system'), 'EnableGameOverlay', '0')
        steam_apps = child(child(child(child(store, 'Software'), 'Valve'), 'Steam'), 'apps')
        for app in apps:
            changed |= setval(child(steam_apps, app), 'OverlayAppEnable', '0')
        if changed:
            tmp = path + '.sil-tmp'
            with open(tmp, 'w', encoding='utf-8', errors='surrogateescape') as f:
                f.write(dump(data))
            os.replace(tmp, path)


if __name__ == '__main__':
    main()
