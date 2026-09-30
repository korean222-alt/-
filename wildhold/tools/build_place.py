#!/usr/bin/env python3
"""src/ 폴더의 Luau 소스를 Roblox Studio에서 바로 여는 .rbxlx 로 묶는다.

사용법:  python3 wildhold/tools/build_place.py
결과:    wildhold/WILDHOLD.rbxlx

Rojo 를 쓰는 경우에는 default.project.json 으로 같은 구조를 동기화할 수 있다.
"""
from __future__ import annotations

import pathlib
import re
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUT = ROOT / "WILDHOLD.rbxlx"
# Studio 에서 FBX 를 가져온 결과(메쉬·텍스처가 Roblox 에 올라간 모델)를 저장한 파일들.
# 있으면 place 에 그대로 넣어서, place 를 다시 만들어도 Studio 에서 또 가져올 필요가 없다.
ENV_MODELS = ROOT / "assets" / "env" / "EnvModels.rbxmx"    # Model "EnvModels" (숲 키트 14개) → ReplicatedStorage
PET_MODELS = ROOT / "assets" / "pets" / "PetModels.rbxmx"   # 펫 Model 들 → ReplicatedStorage/PetModels
BUILD_MODELS = ROOT / "assets" / "build" / "BuildModels.rbxmx"  # Model "BuildModels" (건축 키트) → ReplicatedStorage (있을 때만)

_ref = 0


def ref() -> str:
    global _ref
    _ref += 1
    return f"RBX{_ref:06d}"


def props_xml(props: dict, indent: str) -> str:
    lines = []
    for key, (kind, value) in props.items():
        if kind == "string":
            lines.append(f'{indent}<string name="{key}">{escape(value)}</string>')
        elif kind == "source":
            lines.append(f'{indent}<ProtectedString name="{key}">{escape(value)}</ProtectedString>')
        elif kind == "bool":
            lines.append(f'{indent}<bool name="{key}">{"true" if value else "false"}</bool>')
        elif kind == "float":
            lines.append(f'{indent}<float name="{key}">{value}</float>')
        elif kind == "int":
            lines.append(f'{indent}<int name="{key}">{value}</int>')
        elif kind == "token":
            lines.append(f'{indent}<token name="{key}">{value}</token>')
        elif kind == "color":
            r, g, b = (c / 255 for c in value)
            lines.append(f'{indent}<Color3 name="{key}"><R>{r:.4f}</R><G>{g:.4f}</G><B>{b:.4f}</B></Color3>')
        else:
            raise ValueError(kind)
    return "\n".join(lines)


def item(cls: str, name: str, children=(), indent="  ", **props) -> str:
    all_props = {"Name": ("string", name)}
    all_props.update(props)
    inner = indent + "  "
    body = [f'{indent}<Item class="{cls}" referent="{ref()}">', f"{inner}<Properties>",
            props_xml(all_props, inner + "  "), f"{inner}</Properties>"]
    for child in children:
        body.append(child(inner) if callable(child) else child)
    body.append(f"{indent}</Item>")
    return "\n".join(body)


def script_item(path: pathlib.Path):
    name = path.name
    if name.endswith(".server.lua"):
        cls, name = "Script", name[: -len(".server.lua")]
    elif name.endswith(".client.lua"):
        cls, name = "LocalScript", name[: -len(".client.lua")]
    else:
        cls, name = "ModuleScript", name[: -len(".lua")]
    source = path.read_text(encoding="utf-8")
    return lambda indent: item(cls, name, indent=indent, Source=("source", source))


def folder_item(path: pathlib.Path, name: str | None = None):
    def build(indent):
        children = []
        for child in sorted(path.iterdir()):
            if child.is_dir():
                children.append(folder_item(child))
            elif child.suffix == ".lua":
                children.append(script_item(child))
        return item("Folder", name or path.name, children, indent=indent)
    return build


def saved_models(path: pathlib.Path) -> tuple[list, list]:
    """Studio 가져오기 결과 .rbxmx 에서 최상위 Model Item 들과 메쉬 데이터(SharedStrings)를 꺼낸다. 없으면 빈 목록."""
    if not path.exists():
        return [], []
    text = path.read_text(encoding="utf-8")
    body = text[: text.index("<SharedStrings>")] if "<SharedStrings>" in text else text
    models, depth, start = [], 0, None
    for m in re.finditer(r"<Item |</Item>", body):
        if m.group() == "<Item ":
            if depth == 0:
                start = m.start()
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                models.append(body[start:m.end()])
    shared = re.findall(r"<SharedString md5=.*?</SharedString>", text, re.S)
    return models, shared


def main() -> None:
    env_items, env_shared = saved_models(ENV_MODELS)
    pet_items, pet_shared = saved_models(PET_MODELS)
    build_items, build_shared = saved_models(BUILD_MODELS)
    shared = list(dict.fromkeys(env_shared + pet_shared + build_shared))
    server_children = [script_item(SRC / "server" / "ServerMain.server.lua"), folder_item(SRC / "server" / "Services")]
    client_children = [script_item(SRC / "client" / "ClientMain.client.lua"), folder_item(SRC / "client" / "Controllers")]
    parts = [
        "<?xml version='1.0' encoding='utf-8'?>",
        '<roblox version="4">',
        "  <External>null</External>",
        "  <External>nil</External>",
        # 맵이 넓어서(지름 약 1500) 클라이언트는 가까운 곳만 받는다. 기지 건물은 서버가 Persistent 로 둔다.
        # StreamOutBehavior 2 = Opportunistic (멀어진 곳은 틈날 때 내린다)
        item("Workspace", "Workspace", FilteringEnabled=("bool", True), StreamingEnabled=("bool", True),
             StreamingMinRadius=("int", 128), StreamingTargetRadius=("int", 512), StreamOutBehavior=("token", 2)),
        # Technology 는 스크립트로 바꿀 수 없어서 place 파일에 직접 넣는다. 4 = Future
        item("Lighting", "Lighting",
             Technology=("token", 4), ClockTime=("float", 14), Brightness=("float", 2.4),
             GlobalShadows=("bool", True), ShadowSoftness=("float", 0.25),
             EnvironmentDiffuseScale=("float", 1), EnvironmentSpecularScale=("float", 1),
             Ambient=("color", (70, 78, 92)), OutdoorAmbient=("color", (128, 132, 140)),
             ExposureCompensation=("float", 0.1)),
        item("ReplicatedStorage", "ReplicatedStorage", [
            folder_item(SRC / "shared", "Shared"),
            # 블렌더 펫 4종 (Studio 가져오기 결과). 새 펫은 Studio 에서 가져와 여기에 넣고 PetModels.rbxmx 로 저장
            lambda indent: item("Folder", "PetModels", pet_items, indent=indent),
            *env_items,
            *build_items,
        ]),
        item("ServerScriptService", "ServerScriptService", server_children),
        item("StarterPlayer", "StarterPlayer", [
            lambda indent: item("StarterPlayerScripts", "StarterPlayerScripts", client_children, indent=indent),
        ], CameraMaxZoomDistance=("float", 80), CharacterWalkSpeed=("float", 18)),
        item("StarterGui", "StarterGui"),
        item("StarterPack", "StarterPack"),
        *(["  <SharedStrings>", *("    " + x for x in shared), "  </SharedStrings>"] if shared else []),
        "</roblox>",
        "",
    ]
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT.parent)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
