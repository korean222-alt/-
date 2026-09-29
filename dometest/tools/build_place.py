"""python dometest/tools/build_place.py — 기존 빌더의 XML 포장 방식을 재사용(읽기 전용)."""
from pathlib import Path
import importlib.util
import sys

# 읽기 전용 재사용: 기존 게임 폴더에 __pycache__도 쓰지 않습니다.
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("place_xml", ROOT.parent / "wildhold/tools/build_place.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
src = ROOT / "src"
parts = [
    '<?xml version="1.0" encoding="utf-8"?>', '<roblox version="4">',
    '<External>null</External>', '<External>nil</External>',
    b.item("Workspace", "Workspace", FilteringEnabled=("bool", True)),
    b.item("Lighting", "Lighting", Technology=("token", 4),
           ClockTime=("float", 14), Brightness=("float", 2), GlobalShadows=("bool", True)),
    b.item("ReplicatedStorage", "ReplicatedStorage", [b.folder_item(src / "shared", "Shared"),
        lambda indent: b.item("Folder", "EnvModels", indent=indent)]),
    b.item("ServerScriptService", "ServerScriptService", [b.script_item(src / "server/DomeTest.server.lua")]),
    b.item("StarterPlayer", "StarterPlayer", [lambda indent: b.item("StarterPlayerScripts", "StarterPlayerScripts",
        [b.script_item(src / "client/DayNight.client.lua")], indent=indent)]),
    b.item("StarterGui", "StarterGui"), b.item("StarterPack", "StarterPack"), '</roblox>', '',
]
out = ROOT / "DomeTest.rbxlx"
out.write_text('\n'.join(parts), encoding="utf-8")
print(f"Built {out.name}: {out.stat().st_size:,} bytes")
