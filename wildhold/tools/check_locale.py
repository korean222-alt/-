"""번역 검사: python3 tools/check_locale.py
- 모든 언어 파일(src/shared/Locale/*.lua)에 같은 키가 있는지
- 키마다 {자리표시자} 가 언어끼리 같은지 (번역하다 {name} 을 빠뜨리면 글자가 깨진다)
- 코드에서 쓰는 고정 키(L.M("..."), L.t("..."), {k = "..."}, L.bind(.., "...") 등)가 모두 있는지
- Config 의 id 로 만드는 키(item.<id>, species.<id>, zone.<id> …)가 모두 있는지
- 코드에 한국어 문자열이 남지 않았는지 (tools/find_korean.py)
문제가 있으면 1 로 끝난다.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE = os.path.join(ROOT, "src", "shared", "Locale")
CONFIG = os.path.join(ROOT, "src", "shared", "Config")
ENTRY = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)",?\s*$')
HOLDER = re.compile(r"\{(\w+)\}")


def load(path):
    table = {}
    for line in open(path, encoding="utf-8"):
        m = ENTRY.match(line)
        if m:
            table[m.group(1)] = m.group(2)
    return table


def config_ids(name, pattern):
    text = open(os.path.join(CONFIG, name), encoding="utf-8").read()
    return set(re.findall(pattern, text, re.M))


def block(name, key):
    """Config 파일에서 key = { ... } 블록 안의 1단계 id 들"""
    text = open(os.path.join(CONFIG, name), encoding="utf-8").read()
    start = re.search(r"\b" + key + r"\s*=\s*\{", text)
    if not start:
        return set()
    depth, i, ids = 1, start.end(), set()
    line_start = True
    while i < len(text) and depth > 0:
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif depth == 1 and line_start:
            m = re.match(r"\s*(\w+)\s*=\s*\{", text[i:])
            if m:
                ids.add(m.group(1))
        line_start = ch == "\n"
        i += 1
    return ids


def main():
    problems = []
    langs = {f[:-4]: load(os.path.join(LOCALE, f)) for f in sorted(os.listdir(LOCALE)) if f.endswith(".lua")}
    base = langs["en"]
    for code, table in langs.items():
        for k in sorted(set(base) - set(table)):
            problems.append(f"{code}: missing key {k}")
        for k in sorted(set(table) - set(base)):
            problems.append(f"{code}: extra key {k} (not in en)")
        for k, v in table.items():
            if k in base and set(HOLDER.findall(v)) != set(HOLDER.findall(base[k])):
                problems.append(f"{code}: {k} placeholders {sorted(set(HOLDER.findall(v)))} != en {sorted(set(HOLDER.findall(base[k])))}")

    # 코드에서 쓰는 고정 키
    used = set()
    patterns = [r'\b[LT]\.(?:M|t|has)\(\s*"([\w.]+)"', r'\{\s*k\s*=\s*"([\w.]+)"', r'\b[LT]\.bind\([^,]+,\s*"([\w.]+)"',
                r'"((?:tut|goal|quick|tab|order|settings|phase|lobby|run|pet|pets|wild|build|craft|egg|data|power|result|team|banner)\.[\w.]+)"']
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        if os.path.basename(dirpath) == "Locale":
            continue
        for f in files:
            if f.endswith(".lua"):
                text = open(os.path.join(dirpath, f), encoding="utf-8").read()
                for pattern in patterns:
                    used.update(re.findall(pattern, text))
    for k in sorted(used):
        if k.endswith(".") or k not in base:
            if not k.endswith("."):
                problems.append(f"code uses missing key {k}")

    # Config id 로 만드는 키
    families = {
        "item": block("ItemConfig.lua", "Items"),
        "species": block("PetConfig.lua", "Species"),
        "adult": block("PetConfig.lua", "Species"),
        "trait": block("PetConfig.lua", "Traits"),
        "traitDesc": block("PetConfig.lua", "Traits"),
        "role": config_ids("PetConfig.lua", r'Role = "(\w+)"'),
        "res": set(re.findall(r'"(\w+)"', re.search(r"Order = \{([^}]*)\}", open(os.path.join(CONFIG, "ResourceConfig.lua"), encoding="utf-8").read()).group(1))),
        "perk": block("ShopConfig.lua", "Perks"),
        "zone": block("MapConfig.lua", "Zones"),
        "defense": {k for k in block("DefenseConfig.lua", "return") if k} or config_ids("DefenseConfig.lua", r"^\s{4}(\w+) = \{"),
        "egg": block("EggConfig.lua", "Kinds"),
        "enemy": config_ids("EnemyConfig.lua", r"^\s*(\w+)\s*=\s*\{") & {"Crawler", "Runner", "Brute", "Howler"},
        "station": {"Hand", "Workbench", "Campfire"},
    }
    defense_text = open(os.path.join(CONFIG, "DefenseConfig.lua"), encoding="utf-8").read()
    families["defense"] = set(re.findall(r"^    (\w+) = \{", defense_text, re.M))
    for family, ids in families.items():
        if not ids:
            problems.append(f"no ids found for {family} (check_locale.py needs updating)")
        for i in sorted(ids):
            if f"{family}.{i}" not in base:
                problems.append(f"missing key {family}.{i}")

    korean = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "find_korean.py"), os.path.join(ROOT, "src")],
                            capture_output=True, text=True)
    if korean.returncode != 0:
        problems.append("Korean strings left in code:\n" + korean.stdout)

    for p in problems:
        print("❌", p)
    total = len(base)
    print(f"{'OK' if not problems else 'FAIL'}: {len(langs)} languages ({', '.join(langs)}), {total} keys, {len(used)} static keys used in code")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
