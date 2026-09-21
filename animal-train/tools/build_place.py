#!/usr/bin/env python3
"""src/ 안의 .luau 파일을 읽어 Roblox place 파일(.rbxlx)을 만듭니다.

  python3 tools/build_place.py

만들어지는 것:
  졸졸동물기차.rbxlx  - Studio 에서 바로 열어 Play 할 수 있는 게임 파일
  Install.lua         - 이미 만든 게임에 넣고 싶을 때 쓰는 명령 바 스크립트
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
PLACE_NAME = "졸졸동물기차.rbxlx"

# Roblox 서비스 안에 그대로 들어가는 폴더 구조.
# (StarterPlayerScripts 처럼 폴더가 아닌 클래스는 아래 CLASS_OVERRIDE 로 지정)
CLASS_OVERRIDE = {
    ("StarterPlayer", "StarterPlayerScripts"): "StarterPlayerScripts",
    ("StarterPlayer", "StarterCharacterScripts"): "StarterCharacterScripts",
}

# place 파일에 넣을 서비스 (src 에 폴더가 없어도 만들어 둡니다)
EXTRA_SERVICES = ["Workspace", "Lighting", "ServerStorage", "SoundService"]

_counter = 0


def referent() -> str:
    global _counter
    _counter += 1
    return "RBX%08X" % _counter


def esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def script_class(path: pathlib.Path) -> tuple[str, str]:
    """파일 이름으로 스크립트 종류와 인스턴스 이름을 정합니다."""
    name = path.name
    if name.endswith(".server.luau"):
        return "Script", name[: -len(".server.luau")]
    if name.endswith(".client.luau"):
        return "LocalScript", name[: -len(".client.luau")]
    return "ModuleScript", name[: -len(".luau")]


def render_script(path: pathlib.Path, indent: str) -> list[str]:
    klass, name = script_class(path)
    source = path.read_text(encoding="utf-8")
    lines = [
        f'{indent}<Item class="{klass}" referent="{referent()}">',
        f"{indent}\t<Properties>",
        f'{indent}\t\t<string name="Name">{esc(name)}</string>',
        f'{indent}\t\t<ProtectedString name="Source">{esc(source)}</ProtectedString>',
    ]
    if klass in ("Script", "LocalScript"):
        lines.append(f'{indent}\t\t<bool name="Disabled">false</bool>')
    lines.append(f"{indent}\t</Properties>")
    lines.append(f"{indent}</Item>")
    return lines


def render_folder(path: pathlib.Path, service: str, indent: str) -> list[str]:
    klass = CLASS_OVERRIDE.get((service, path.name), "Folder")
    lines = [
        f'{indent}<Item class="{klass}" referent="{referent()}">',
        f"{indent}\t<Properties>",
        f'{indent}\t\t<string name="Name">{esc(path.name)}</string>',
        f"{indent}\t</Properties>",
    ]
    lines += render_children(path, service, indent + "\t")
    lines.append(f"{indent}</Item>")
    return lines


def render_children(path: pathlib.Path, service: str, indent: str) -> list[str]:
    lines: list[str] = []
    for child in sorted(path.iterdir(), key=lambda item: (item.is_file(), item.name)):
        if child.is_dir():
            lines += render_folder(child, service, indent)
        elif child.suffix == ".luau":
            lines += render_script(child, indent)
    return lines


def render_service(name: str, path: pathlib.Path | None, indent: str, extra: list[str] | None = None) -> list[str]:
    lines = [
        f'{indent}<Item class="{name}" referent="{referent()}">',
        f"{indent}\t<Properties>",
        f'{indent}\t\t<string name="Name">{name}</string>',
        f"{indent}\t</Properties>",
    ]
    if extra:
        lines += [indent + "\t" + row for row in extra]
    if path is not None and path.is_dir():
        lines += render_children(path, name, indent + "\t")
    lines.append(f"{indent}</Item>")
    return lines


def spawn_location() -> list[str]:
    """월드가 만들어지기 전에도 떨어지지 않도록 스폰 발판 하나를 넣어 둡니다.
    크기·색·방향은 WorldService 가 다시 잡아 줍니다."""
    return [
        f'<Item class="SpawnLocation" referent="{referent()}">',
        "\t<Properties>",
        '\t\t<string name="Name">MainSpawn</string>',
        '\t\t<bool name="Anchored">true</bool>',
        '\t\t<CoordinateFrame name="CFrame">',
        "\t\t\t<X>0</X><Y>0.5</Y><Z>62</Z>",
        "\t\t\t<R00>1</R00><R01>0</R01><R02>0</R02>",
        "\t\t\t<R10>0</R10><R11>1</R11><R12>0</R12>",
        "\t\t\t<R20>0</R20><R21>0</R21><R22>1</R22>",
        "\t\t</CoordinateFrame>",
        "\t</Properties>",
        "</Item>",
    ]


def build_place() -> str:
    lines = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime"'
        ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
        ' xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        "\t<External>null</External>",
        "\t<External>nil</External>",
    ]

    # Workspace : 스폰 발판만 미리 넣습니다 (섬은 서버가 만듭니다)
    lines += render_service(
        "Workspace",
        None,
        "\t",
        extra=spawn_location(),
    )

    for service in ["ReplicatedStorage", "ServerScriptService", "StarterPlayer"]:
        path = SRC / service
        lines += render_service(service, path if path.is_dir() else None, "\t")

    for service in ["Lighting", "ServerStorage", "SoundService", "StarterGui", "Players"]:
        lines += render_service(service, None, "\t")

    lines.append("</roblox>")
    return "\n".join(lines) + "\n"


INSTALL_HEADER = """--[==[
  졸졸 동물 기차 - 설치 스크립트 (place 파일을 쓰지 않고 넣고 싶을 때)

  쓰는 방법
    1) Roblox Studio 에서 게임을 엽니다.
    2) VIEW 탭 → Command Bar 를 켭니다.
    3) 이 파일 전체를 복사해서 명령 바에 붙여넣고 Enter 를 누릅니다.
    4) 출력 창에 "설치 완료" 가 나오면 Play 를 누르세요.
]==]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function folder(parent, name)
\tlocal existing = parent:FindFirstChild(name)
\tif existing and not existing:IsA("Folder") then
\t\texisting:Destroy()
\t\texisting = nil
\tend
\tif not existing then
\t\texisting = Instance.new("Folder")
\t\texisting.Name = name
\t\texisting.Parent = parent
\tend
\treturn existing
end

local function script_(parent, class, name, source)
\tlocal existing = parent:FindFirstChild(name)
\tif existing then
\t\texisting:Destroy()
\tend
\tlocal made = Instance.new(class)
\tmade.Name = name
\tmade.Source = source
\tmade.Parent = parent
\treturn made
end

local roots = {
\tReplicatedStorage = ReplicatedStorage,
\tServerScriptService = ServerScriptService,
\tStarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"),
}

"""


def build_install() -> str:
    parts = [INSTALL_HEADER]

    def add(root_key: str, folders: list[str], path: pathlib.Path) -> None:
        klass, name = script_class(path)
        source = path.read_text(encoding="utf-8")
        if "]==]" in source:
            raise SystemExit(f"긴 문자열과 충돌: {path}")
        parent = f"roots.{root_key}"
        for item in folders:
            parent = f'folder({parent}, "{item}")'
        parts.append(f'script_({parent}, "{klass}", "{name}", [==[\n{source}]==])\n')

    for path in sorted((SRC / "ReplicatedStorage").rglob("*.luau")):
        rel = path.relative_to(SRC / "ReplicatedStorage")
        add("ReplicatedStorage", list(rel.parent.parts), path)

    for path in sorted((SRC / "ServerScriptService").rglob("*.luau")):
        rel = path.relative_to(SRC / "ServerScriptService")
        add("ServerScriptService", list(rel.parent.parts), path)

    scripts_dir = SRC / "StarterPlayer" / "StarterPlayerScripts"
    for path in sorted(scripts_dir.rglob("*.luau")):
        rel = path.relative_to(scripts_dir)
        add("StarterPlayerScripts", list(rel.parent.parts), path)

    parts.append('print("[졸졸 동물 기차] 설치 완료. Play 를 눌러 보세요.")\n')
    return "\n".join(parts)


BUNDLE_HEADER = """-- 테스트용 소스 묶음 (tools/build_place.py 가 자동으로 만듭니다. 직접 고치지 마세요)
ENV.GAME_SOURCES = {
"""


def build_bundle() -> str:
    rows = [BUNDLE_HEADER]
    for service in ["ReplicatedStorage", "ServerScriptService", "StarterPlayer"]:
        base = SRC / service
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.luau")):
            klass, name = script_class(path)
            rel = path.relative_to(SRC)
            parts = list(rel.parent.parts) + [name]
            source = path.read_text(encoding="utf-8")
            if "]==]" in source:
                raise SystemExit(f"긴 문자열과 충돌: {path}")
            rows.append(
                "\t{ path = \"%s\", class = \"%s\", source = [==[\n%s]==] },"
                % ("/".join(parts), klass, source)
            )
    rows.append("}\n")
    return "\n".join(rows)


def main() -> int:
    if not SRC.is_dir():
        raise SystemExit("src 폴더를 찾을 수 없습니다")

    place = ROOT / PLACE_NAME
    place.write_text(build_place(), encoding="utf-8")

    install = ROOT / "Install.lua"
    install.write_text(build_install(), encoding="utf-8")

    bundle = ROOT / "tools" / "testkit" / "bundle.luau"
    if bundle.parent.is_dir():
        bundle.write_text(build_bundle(), encoding="utf-8")

    scripts = list(SRC.rglob("*.luau"))
    print(f"스크립트 {len(scripts)}개 → {place.name} ({place.stat().st_size // 1024} KB)")
    print(f"              → {install.name} ({install.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
