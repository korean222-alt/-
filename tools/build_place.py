#!/usr/bin/env python3
"""
build_place.py — game/ 아래의 Luau 소스를 .rbxl 플레이스 파일에 심는다.

  python3 tools/build_place.py place/CursedBarrel_Phase5.rbxl place/CursedBarrel_Phase8.rbxl

동작
  1. rbxconv 로 이진 .rbxl → .rbxlx(XML) 변환
  2. game/ 트리를 훑어 스크립트 Source 를 교체하거나 새 스크립트를 만든다
  3. 없는 중간 Folder 는 자동으로 만든다
  4. 다시 이진 .rbxl 로 되돌린다

파일 이름 규칙
  Name.lua         → ModuleScript
  Name.server.lua  → Script
  Name.client.lua  → LocalScript
"""
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
CONV = os.path.join(ROOT, "tools", "rbxconv", "target", "release", "rbxconv")

CLASS_OF_SUFFIX = [(".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")]

# 서버도 부팅할 때 만들지만, 파일에 미리 넣어 두면
# 클라이언트의 WaitForChild 가 기다리지 않고 Studio 탐색기에서도 바로 보인다.
REQUIRED_INSTANCES = [
    (
        ["ReplicatedStorage", "CursedBarrel", "Remotes"],
        "RemoteEvent",
        [
            "SelectSlot", "PresentationCue",
            "CatchPrompt", "CatchInput", "CatchResult", "EquipSkin",
            "ShopRequest", "ShopResult",
            "Sabotage", "SabotageCue", "QuestUpdate",
        ],
    ),
]


def props(item):
    node = item.find("Properties")
    if node is None:
        node = ET.SubElement(item, "Properties")
    return node


def prop_map(item):
    return {c.get("name"): c for c in props(item)}


def name_of(item):
    node = prop_map(item).get("Name")
    return node.text if node is not None and node.text else ""


def child_named(parent, name, classes=None):
    for item in parent.findall("Item"):
        if name_of(item) == name and (classes is None or item.get("class") in classes):
            return item
    return None


class Builder:
    def __init__(self, tree):
        self.tree = tree
        self.root = tree.getroot()
        used = set()
        for item in self.root.iter("Item"):
            ref = item.get("referent")
            if ref and ref.isdigit():
                used.add(int(ref))
        self.next_ref = (max(used) if used else 0) + 1000
        self.created = []
        self.updated = []

    def new_ref(self):
        self.next_ref += 1
        return str(self.next_ref)

    def make_item(self, parent, cls, name):
        item = ET.SubElement(parent, "Item")
        item.set("class", cls)
        item.set("referent", self.new_ref())
        node = ET.SubElement(item, "Properties")
        label = ET.SubElement(node, "string")
        label.set("name", "Name")
        label.text = name
        return item

    def ensure_folder(self, parent, name):
        found = child_named(parent, name)
        if found is not None:
            return found
        self.created.append(name + "/")
        return self.make_item(parent, "Folder", name)

    def ensure_script(self, parent, name, cls, source):
        item = child_named(parent, name, {"Script", "LocalScript", "ModuleScript"})
        if item is None:
            item = self.make_item(parent, cls, name)
            self.created.append(name + " (" + cls + ")")
        else:
            item.set("class", cls)
            self.updated.append(name)
        node = props(item)
        for child in list(node):
            if child.get("name") == "Source":
                node.remove(child)
        src = ET.SubElement(node, "string")
        src.set("name", "Source")
        src.text = source
        return item

    def ensure_instance(self, parent, name, cls):
        found = child_named(parent, name)
        if found is not None:
            return found
        self.created.append("%s (%s)" % (name, cls))
        return self.make_item(parent, cls, name)

    def ensure_required(self):
        for path, cls, names in REQUIRED_INSTANCES:
            node = self.top_level(path[0])
            for step in path[1:]:
                node = self.ensure_folder(node, step)
            for name in names:
                self.ensure_instance(node, name, cls)

    def top_level(self, name):
        found = child_named(self.root, name)
        if found is None:
            raise SystemExit("플레이스에 최상위 '%s' 가 없습니다." % name)
        return found


def walk(builder, disk_dir, parent):
    for entry in sorted(os.listdir(disk_dir)):
        path = os.path.join(disk_dir, entry)
        if os.path.isdir(path):
            walk(builder, path, builder.ensure_folder(parent, entry))
            continue
        for suffix, cls in CLASS_OF_SUFFIX:
            if entry.endswith(suffix):
                with open(path, encoding="utf-8") as handle:
                    builder.ensure_script(parent, entry[: -len(suffix)], cls, handle.read())
                break


def convert(mode, src, dst):
    if not os.path.exists(CONV):
        raise SystemExit("rbxconv 가 없습니다. `cargo build --release --manifest-path tools/rbxconv/Cargo.toml` 를 먼저 실행하세요.")
    subprocess.run([CONV, mode, src, dst], check=True)


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    source_place, target_place = sys.argv[1], sys.argv[2]
    work_in = target_place + ".in.rbxlx"
    work_out = target_place + ".out.rbxlx"

    convert("tox", source_place, work_in)
    tree = ET.parse(work_in)
    builder = Builder(tree)

    builder.ensure_required()

    for service in sorted(os.listdir(GAME)):
        disk = os.path.join(GAME, service)
        if os.path.isdir(disk):
            walk(builder, disk, builder.top_level(service))

    tree.write(work_out, encoding="utf-8", xml_declaration=True)
    convert("tob", work_out, target_place)
    os.remove(work_in)
    os.remove(work_out)

    print("새로 만든 것 %d개: %s" % (len(builder.created), ", ".join(builder.created) or "없음"))
    print("내용을 바꾼 스크립트 %d개: %s" % (len(builder.updated), ", ".join(builder.updated) or "없음"))
    print("완성: " + target_place)


if __name__ == "__main__":
    main()
