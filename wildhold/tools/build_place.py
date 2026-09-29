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
# Studio 에서 EnvModels.fbx 를 가져온 결과(메쉬·텍스처가 Roblox 에 올라간 MeshPart 14개)를 저장한 모델 파일.
# 있으면 ReplicatedStorage/EnvModels 로 그대로 넣어서 place 를 다시 만들어도 숲 키트를 또 가져올 필요가 없다.
ENV_MODELS = ROOT / "assets" / "env" / "EnvModels.rbxmx"

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


def env_models() -> tuple[list, list]:
    """EnvModels.rbxmx 에서 모델 Item 과 그 메쉬 데이터(SharedStrings)를 꺼낸다. 없으면 빈 목록."""
    if not ENV_MODELS.exists():
        return [], []
    text = ENV_MODELS.read_text(encoding="utf-8")
    start = text.index('<Item class="Model"')
    end = text.index("<SharedStrings>")
    model = text[start:end].rstrip()
    shared = re.findall(r"<SharedString md5=.*?</SharedString>", text, re.S)
    return [model], shared


def main() -> None:
    env_items, env_shared = env_models()
    server_children = [script_item(SRC / "server" / "ServerMain.server.lua"), folder_item(SRC / "server" / "Services")]
    client_children = [script_item(SRC / "client" / "ClientMain.client.lua"), folder_item(SRC / "client" / "Controllers")]
    parts = [
        "<?xml version='1.0' encoding='utf-8'?>",
        '<roblox version="4">',
        "  <External>null</External>",
        "  <External>nil</External>",
        item("Workspace", "Workspace", FilteringEnabled=("bool", True)),
        # Technology 는 스크립트로 바꿀 수 없어서 place 파일에 직접 넣는다. 4 = Future
        item("Lighting", "Lighting",
             Technology=("token", 4), ClockTime=("float", 14), Brightness=("float", 2.4),
             GlobalShadows=("bool", True), ShadowSoftness=("float", 0.25),
             EnvironmentDiffuseScale=("float", 1), EnvironmentSpecularScale=("float", 1),
             Ambient=("color", (70, 78, 92)), OutdoorAmbient=("color", (128, 132, 140)),
             ExposureCompensation=("float", 0.1)),
        item("ReplicatedStorage", "ReplicatedStorage", [
            folder_item(SRC / "shared", "Shared"),
            # 블렌더에서 만든 펫 FBX 를 Studio 로 가져온 뒤 여기에 넣는다 (docs/PET_IMPORT_GUIDE.md)
            lambda indent: item("Folder", "PetModels", indent=indent),
            *env_items,
        ]),
        item("ServerScriptService", "ServerScriptService", server_children),
        item("StarterPlayer", "StarterPlayer", [
            lambda indent: item("StarterPlayerScripts", "StarterPlayerScripts", client_children, indent=indent),
        ], CameraMaxZoomDistance=("float", 80), CharacterWalkSpeed=("float", 18)),
        item("StarterGui", "StarterGui"),
        item("StarterPack", "StarterPack"),
        *(["  <SharedStrings>", *("    " + x for x in env_shared), "  </SharedStrings>"] if env_shared else []),
        "</roblox>",
        "",
    ]
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT.parent)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
