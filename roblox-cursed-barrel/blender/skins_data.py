"""Reads Knife / Barrel / Ghost skins (colours, materials, rarity, price) out of GameConfig.lua.

Keeps the Blender thumbnails in sync with the game: whatever colour the game paints, the picture shows.
"""
import os
import re

GAMECONFIG = os.environ.get("GAMECONFIG_LUA")

RGB = re.compile(r"Color3\.fromRGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)")


def _color(v):
    m = RGB.search(v)
    return tuple(int(x) for x in m.groups()) if m else None


def _fields(block):
    out = {}
    for key, val in re.findall(r"(\w+)\s*=\s*(Color3\.fromRGB\([^)]*\)|Enum\.Material\.\w+|\"[^\"]*\"|-?[\d.]+|true|false)", block):
        if key in out:
            continue
        if val.startswith("Color3"):
            out[key] = _color(val)
        elif val.startswith("Enum.Material."):
            out[key] = val.split(".")[-1]
        elif val.startswith('"'):
            out[key] = val.strip('"')
        elif val in ("true", "false"):
            out[key] = val == "true"
        else:
            out[key] = float(val)
    fx = re.search(r"fx\s*=\s*\{([^}]*)\}", block)
    out["fx"] = _fields_flat(fx.group(1)) if fx else {}
    return out


def _fields_flat(text):
    out = {}
    for key, val in re.findall(r"(\w+)\s*=\s*(Color3\.fromRGB\([^)]*\)|true|false|-?[\d.]+|\"[^\"]*\")", text):
        out[key] = _color(val) if val.startswith("Color3") else (val == "true" if val in ("true", "false") else val.strip('"'))
    return out


def _section(src, name):
    start = src.index("\n\t%s = {" % name)
    depth = 0
    i = src.index("{", start)
    j = i
    while True:
        c = src[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
        j += 1


def _entries(body):
    items, depth, cur = [], 0, None
    for i, c in enumerate(body):
        if c == "{":
            depth += 1
            if depth == 1:
                cur = i
        elif c == "}":
            depth -= 1
            if depth == 0 and cur is not None:
                items.append(body[cur + 1:i])
                cur = None
    return items


def load(path=None):
    path = path or GAMECONFIG
    src = open(path, encoding="utf-8").read()
    skins = {}
    for kind in ("Knife", "Barrel", "Ghost"):
        skins[kind] = [_fields(e) for e in _entries(_section(src, kind))]
    # Phase 9 dragon themes (loop at the end of GameConfig)
    themes = re.search(r"local themes = \{(.*?)\n\}", src, re.S)
    loop_price = {}
    for kind in ("Knife", "Barrel", "Ghost"):
        m = re.search(r"table\.insert\(GameConfig\.Skins\.%s,\{[^}]*?price=(\d+)" % kind, src)
        loop_price[kind] = int(m.group(1)) if m else 499000
    for t in _entries(themes.group(1)):
        f = _fields_flat(t)
        tid = re.search(r'id="([^"]+)"', t).group(1)
        name = re.search(r'name="([^"]+)"', t).group(1)
        col, acc = f["color"], f["accent"]
        fx = {"theme": "dragon", "emit": col, "trail": col, "halo": acc, "spark": True, "accent": acc, "mythic": True}
        skins["Knife"].append(dict(id=tid, shape="fang", name=name + "의 송곳니", rarity="mythic", price=loop_price["Knife"], blade=col,
                                   bladeMaterial="Neon", handle=(19, 27, 40), handleMaterial="Metal", guard=acc, trail=col, glow=0.6, fx=fx))
        skins["Barrel"].append(dict(id=tid, name=name + "의 봉인", rarity="mythic", price=loop_price["Barrel"], body=(24, 36, 49), bodyMaterial="Slate",
                                    hoop=acc, hoopMaterial="Metal", lid=col, glow=col, fx=fx))
        skins["Ghost"].append(dict(id=tid, name=name + "의 수호자", rarity="mythic", price=loop_price["Ghost"], coat=(25, 39, 56), skin=col,
                                   hat=(20, 28, 42), accent=acc, aura=col, fx=fx))
    return skins


if __name__ == "__main__":
    import json
    import sys
    data = load(sys.argv[1])
    for k, v in data.items():
        print(k, len(v))
        for s in v:
            print("  ", s["id"], s.get("rarity"), s.get("price"), s.get("shape", ""))
