#!/usr/bin/env python3
"""
build_bundle.py — 테스트에서 쓸 모듈 묶음을 만든다.

Luau CLI 에는 io 가 없어 실행 중에 파일을 읽을 수 없다.
그래서 모듈 소스를 함수로 감싼 Lua 파일 하나를 미리 만들어 둔다.
소스는 한 글자도 고치지 않는다. 앞에 "전역을 지역 변수로 가리는 줄"만 덧붙인다.

  python3 tests/build_bundle.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "bundle.lua")

SHADOWED = [
    "game", "workspace", "Instance", "Vector3", "Vector2", "Color3", "CFrame",
    "UDim", "UDim2", "Enum", "Random", "task", "typeof", "require", "script",
    "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "NumberRange",
    "TweenInfo", "warn",
]

MODULES = {
    "GameConfig": "game/ReplicatedStorage/CursedBarrel/Shared/GameConfig.lua",
    "TableConfig": "game/ReplicatedStorage/CursedBarrel/Shared/TableConfig.lua",
    "Utility": "game/ReplicatedStorage/CursedBarrel/Shared/Utility.lua",
    "SkinFX": "game/ReplicatedStorage/CursedBarrel/Shared/SkinFX.lua",
    "RoundService": "game/ServerScriptService/CursedBarrel/Services/RoundService.lua",
    "TableService": "tests/doubles/TableService.lua",
    "RankingService": "tests/doubles/RankingService.lua",
    "ProfileService": "tests/doubles/ProfileService.lua",
}


def preamble():
    lines = ["local __env = ...\n"]
    lines += ["local %s = __env.%s\n" % (name, name) for name in SHADOWED]
    return "".join(lines)


CLIENT = "game/StarterPlayer/StarterPlayerScripts/Controllers/Phase4Controller.client.lua"


def slice_block(source, start_marker, end_marker):
    """start_marker 로 시작해 end_marker 로 끝나는 줄까지를 그대로 잘라 온다."""
    start = source.index(start_marker)
    end = source.index(end_marker, start) + len(end_marker)
    return source[start:end]


def camera_module():
    """
    Phase4Controller 안의 카메라 계산만 떼어 와 테스트에서 돌릴 수 있게 감싼다.
    ★ 계산식은 한 글자도 고치지 않는다. 실제로 화면에 쓰이는 그 코드를 그대로 검사한다.
    """
    with open(os.path.join(ROOT, CLIENT), encoding="utf-8") as handle:
        source = handle.read()

    scare = slice_block(source, "local SCARE = {", "\n}")
    close_shot = slice_block(source, "local function closeShot(model, pos, elapsed)", "\nend")

    return "\n".join([
        "local __env = ...",
        "local Vector3 = __env.Vector3",
        "local CFrame = __env.CFrame",
        scare,
        "local ghostHeight = SCARE.GhostFallback",
        "-- 테스트가 넘겨 준 값을 쓰는 아주 작은 대역들",
        "local scene = { lid = Vector3.new(0, 0, 0), direction = Vector3.new(0, 0, 1) }",
        "local function lidTop() return scene.lid end",
        "local function facing() return scene.direction end",
        close_shot,
        "return {",
        "\tSCARE = SCARE,",
        "\tcloseShot = closeShot,",
        "\tscene = scene,",
        "\tsetGhostHeight = function(value) ghostHeight = value end,",
        "\tgetGhostHeight = function() return ghostHeight end,",
        "}",
    ])


def main():
    parts = ["-- 자동 생성 파일입니다. tests/build_bundle.py 가 만듭니다. 직접 고치지 마세요.\n"]
    parts.append("local bundle = {}\n\n")
    parts.append('bundle["CameraMath"] = function(...)\n')
    parts.append(camera_module())
    parts.append("\nend\n\n")

    for name, path in sorted(MODULES.items()):
        with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
            source = handle.read()
        parts.append('bundle["%s"] = function(...)\n' % name)
        parts.append(preamble())
        parts.append(source)
        parts.append("\nend\n\n")
    parts.append("return bundle\n")

    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("".join(parts))
    print("만들었습니다: %s (%d개 모듈)" % (OUT, len(MODULES)))


if __name__ == "__main__":
    main()
