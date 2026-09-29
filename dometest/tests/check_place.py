"""생성물의 스크립트 일치 및 기본 조작 유지 검사. Roblox 실행 검사는 아님."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
tree = ET.parse(root / "DomeTest.rbxlx")
scripts = tree.findall('.//ProtectedString[@name="Source"]')
sources = list((root / 'src').rglob('*.lua'))
assert sorted(s.text for s in scripts) == sorted(p.read_text(encoding='utf-8') for p in sources)
items = tree.findall('.//Item')
assert len({i.attrib['referent'] for i in items}) == len(items)
assert len(tree.findall('.//Item[@class="Script"]')) == 1
assert len(tree.findall('.//Item[@class="LocalScript"]')) == 1
for prop in ('Gravity', 'CameraMode', 'CameraMaxZoomDistance', 'CharacterWalkSpeed'):
    assert not tree.findall(f'.//*[@name="{prop}"]')
assert not any('wildhold/src' in s.text for s in scripts)
print('PASS: XML, embedded sources, unique references, default player/camera/gravity')
