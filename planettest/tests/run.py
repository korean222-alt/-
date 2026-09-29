"""python planettest/tests/run.py --luau /path/to/luau --compiler /path/to/luau-compile"""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
parser.add_argument('--compiler', default='luau-compile')
args = parser.parse_args()
tree = ET.parse(ROOT / 'PlanetTest.rbxlx')
sources = list((ROOT / 'src').rglob('*.lua'))
assert sorted(n.text for n in tree.findall('.//ProtectedString[@name="Source"]')) == sorted(p.read_text(encoding='utf-8') for p in sources)
refs = [n.attrib['referent'] for n in tree.findall('.//Item')]
assert len(refs) == len(set(refs))
assert tree.find('.//string[@name="Value"]').text.startswith('MIT License')
assert not tree.findall('.//Item[@class="Terrain"]')
for path in sources:
    subprocess.run([args.compiler, '--null', str(path)], check=True, capture_output=True)
print(f'PASS: XML, embedded license, exact {len(sources)} sources, Luau compilation', flush=True)

files = {}
for name in ('api.lua', 'mock/datatypes.luau', 'mock/roblox.luau', 'mock/env.luau'):
    files['mock/' + name] = (ROOT.parent / 'wildhold/tests' / name).read_text(encoding='utf-8')
for path in sources:
    files[path.relative_to(ROOT / 'src').as_posix()] = path.read_text(encoding='utf-8')
prefix = 'local FILES = {\n' + '\n'.join(f'[{json.dumps(k)}]={json.dumps(v, ensure_ascii=False)},' for k,v in files.items()) + '\n}\n'
prefix += 'local function source(name) return assert(loadstring(FILES[name], name)) end\n'
test = prefix + (ROOT / 'tests/headless.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='planettest-') as temp:
    bundle = Path(temp) / 'headless.luau'
    bundle.write_text(test, encoding='utf-8')
    subprocess.run([args.luau, str(bundle)], check=True)
