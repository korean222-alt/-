"""@rbxts/types 의 d.ts 에서 Roblox 클래스/속성/메서드/Enum 목록을 뽑아 Luau 테이블(api.lua)로 만든다.
테스트 하네스가 이 목록으로 "없는 속성 쓰기, 읽기 전용 속성 쓰기, 잘못된 Enum" 을 잡아낸다.
사용법: python3 gen_api.py <rbxts package 경로> <출력 api.lua>
"""
import re
import sys

pkg, out = sys.argv[1], sys.argv[2]
none = open(f"{pkg}/include/generated/None.d.ts", encoding="utf-8").read().splitlines()
enums_src = open(f"{pkg}/include/generated/enums.d.ts", encoding="utf-8").read().splitlines()

classes, creatable, services = {}, set(), set()
cur, block = None, None
prop_re = re.compile(r"^    (readonly )?([A-Za-z_]\w*)(\?)?: (.+);$")
meth_re = re.compile(r"^    ([A-Za-z_]\w*)(<[^>]*>)?\(this: ")
for line in none:
    m = re.match(r"^interface (\w+)(?:<[^{]*?>)?(?: extends (\w+)(?:<[^{]*>)?(?:, [\w<>, ]+)?)? \{", line)
    if m:
        name = m.group(1)
        if name == "CreatableInstances":
            block, cur = "creatable", None
        elif name == "Services":
            block, cur = "services", None
        else:
            block = "class"
            sup = (m.group(2) or "").split(",")[0].strip() or None
            cur = classes.setdefault(name, {"super": sup, "props": {}, "methods": set()})
        continue
    if line.startswith("}"):
        cur, block = None, None
        continue
    if block == "creatable":
        mm = re.match(r"^    (\w+): \w+;", line)
        if mm:
            creatable.add(mm.group(1))
    elif block == "services":
        mm = re.match(r"^    (\w+): \w+;", line)
        if mm:
            services.add(mm.group(1))
    elif block == "class" and cur is not None:
        mm = meth_re.match(line)
        if mm:
            cur["methods"].add(mm.group(1))
            continue
        mm = prop_re.match(line)
        if mm and not mm.group(2).startswith("_nominal"):
            cur["props"][mm.group(2)] = {"ro": bool(mm.group(1)), "type": mm.group(4)}

enums, cur_enum = {}, None
for line in enums_src:
    m = re.match(r"^    export namespace (\w+) \{", line)
    if m:
        cur_enum = enums.setdefault(m.group(1), {})
        continue
    m = re.match(r"^        export interface (\w+) extends globalThis\.EnumItem", line)
    if m and cur_enum is not None:
        cur_enum[m.group(1)] = len(cur_enum)


def simple(t):
    t = t.strip()
    parts = [p.strip() for p in t.split("|")]
    nullable = "undefined" in parts
    parts = [p for p in parts if p != "undefined"]
    kinds = []
    for p in parts:
        if p in ("boolean", "number", "string"):
            kinds.append(p)
        elif p.startswith("Enum."):
            kinds.append("enum:" + p[5:])
        elif p.startswith("RBXScriptSignal"):
            kinds.append("signal")
        elif p in ("Vector3", "CFrame", "Color3", "UDim2", "UDim", "Vector2", "NumberSequence", "ColorSequence",
                   "NumberRange", "Rect", "PhysicalProperties", "Font", "Content", "BrickColor", "Ray", "Region3", "Faces", "Axes"):
            kinds.append(p)
        elif re.match(r"^[A-Z]\w*$", p) and p in classes:
            kinds.append("instance")
        else:
            kinds.append("any")
    return ("?" if nullable else "") + ",".join(kinds or ["any"])


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


lines = ["-- 자동 생성 (tests/gen_api.py). 손으로 고치지 않는다.", "return {", "Classes = {"]
for name, c in sorted(classes.items()):
    props = ", ".join(f"{p}={{{'true' if v['ro'] else 'false'},{lua_str(simple(v['type']))}}}" for p, v in sorted(c["props"].items()))
    meths = ", ".join(f"{m}=true" for m in sorted(c["methods"]))
    sup = lua_str(c["super"]) if c["super"] else "nil"
    lines.append(f"  {name}={{Super={sup}, Props={{{props}}}, Methods={{{meths}}}}},")
lines.append("},")
lines.append("Creatable = {" + ", ".join(f"{n}=true" for n in sorted(creatable)) + "},")
lines.append("Services = {" + ", ".join(f"{n}=true" for n in sorted(services)) + "},")
lines.append("Enums = {")
for name, items in sorted(enums.items()):
    lines.append(f"  {name}={{" + ", ".join(f"{k}={v}" for k, v in items.items()) + "},")
lines.append("},")
lines.append("}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(f"classes={len(classes)} creatable={len(creatable)} services={len(services)} enums={len(enums)}")
