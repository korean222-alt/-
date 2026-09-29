"""python planettest/tools/build_place.py — src를 단일 PlanetTest.rbxlx로 포장."""
from pathlib import Path
import importlib.util
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
# 기존 XML 빌더를 읽기 전용으로 참고/재사용. 캐시도 기존 폴더에 쓰지 않습니다.
spec = importlib.util.spec_from_file_location("place_xml", ROOT.parent / "wildhold/tools/build_place.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
src = ROOT / "src"
notice = (ROOT / "third_party/EgoMoose-LICENSE.txt").read_text(encoding="utf-8")
notice += '\n\n' + (ROOT / "third_party/README.md").read_text(encoding="utf-8")
parts = [
    '<?xml version="1.0" encoding="utf-8"?>', '<roblox version="4">',
    '<External>null</External>', '<External>nil</External>',
    b.item("Workspace", "Workspace", FilteringEnabled=("bool", True), StreamingEnabled=("bool", False),
           FallenPartsDestroyHeight=("float", -50000)),
    b.item("Lighting", "Lighting", Technology=("token", 4), ClockTime=("float", 14),
           Brightness=("float", 2), GlobalShadows=("bool", True)),
    b.item("ReplicatedStorage", "ReplicatedStorage", [b.folder_item(src / "shared", "Shared"),
        lambda indent: b.item("Folder", "EnvModels", indent=indent),
        lambda indent: b.item("StringValue", "ThirdPartyNotices", indent=indent, Value=("string", notice))]),
    b.item("ServerScriptService", "ServerScriptService", [b.script_item(src / "server/PlanetTest.server.lua")]),
    b.item("StarterPlayer", "StarterPlayer", [lambda indent: b.item("StarterPlayerScripts", "StarterPlayerScripts",
        [b.script_item(src / "client/ClientMain.client.lua"), b.folder_item(src / "client/Modules")], indent=indent)],
        DevComputerMovementMode=("token", 1), DevTouchMovementMode=("token", 1), EnableMouseLockOption=("bool", False)),
    b.item("StarterGui", "StarterGui"), b.item("StarterPack", "StarterPack"), '</roblox>', '',
]
out = ROOT / "PlanetTest.rbxlx"
out.write_text('\n'.join(parts), encoding="utf-8")
print(f"Built {out.name}: {out.stat().st_size:,} bytes")
