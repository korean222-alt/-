"""Luau 로 직접 실행하는 검사. (Roblox 엔진이 아니라 luau 명령줄 실행기)

    python tests/run_luau.py path/to/luau

Shared 모듈을 require 할 수 있게 한 파일로 묶어서 실행한다.
Vector3 · Color3 는 검사에 필요한 연산만 흉내 낸다.
"""
from pathlib import Path
import subprocess, sys, tempfile

root = Path(__file__).resolve().parents[1]
shared = root / 'game/ReplicatedStorage/CursedBarrel/Shared'
luau = sys.argv[1] if len(sys.argv) > 1 else 'luau'

PRELUDE = r'''
local V = {}
V.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X*self.X + self.Y*self.Y + self.Z*self.Z) end
	if key == "Unit" then local m = math.sqrt(self.X*self.X + self.Y*self.Y + self.Z*self.Z); return Vector3.new(self.X/m, self.Y/m, self.Z/m) end
	return V[key]
end
function V.__add(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function V.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function V.__unm(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
function V.__mul(a, b)
	if type(a) == "number" then return Vector3.new(b.X*a, b.Y*a, b.Z*a) end
	if type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
	return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
function V.__div(a, b) return Vector3.new(a.X/b, a.Y/b, a.Z/b) end
function V.Cross(a, b) return Vector3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function V.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = function(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V) end }
Color3 = { fromRGB = function(r, g, b) return {r, g, b} end }
local MODULES = {}
local cache = {}
function require(ref)
	local name = ref.__name
	if cache[name] == nil then cache[name] = assert(MODULES[name], name)() end
	return cache[name]
end
script = { Parent = setmetatable({}, { __index = function(_, key) return { __name = key } end }) }
'''

def bundle(test):
    parts = [PRELUDE]
    for name in ('ShipLayout', 'KrakenLayout'):
        parts.append(f'MODULES.{name} = function()\n{(shared / (name + ".lua")).read_text()}\nend\n')
    parts.append((root / 'tests' / test).read_text())
    return '\n'.join(parts)

def literal(text):
    marker = '===='
    while ']' + marker + ']' in text:
        marker += '='
    return '[' + marker + '[' + text + ']' + marker + ']'


def behavior():
    # tests/behavior.lua 를 번역 없이 Luau 로 돌린다. (run.py 는 Lua 5.4 로 돌린다)
    sources = {p.stem: p.read_text() for p in sorted((root / 'game').rglob('*.lua'))}
    loader = 'SOURCES={\n' + ',\n'.join('[ ' + literal(k) + ' ]=' + literal(v) for k, v in sources.items()) + '}\n'
    return loader + (root / 'tests/behavior.lua').read_text()


def run(label, source):
    with tempfile.NamedTemporaryFile('w', suffix='.luau', delete=False) as handle:
        handle.write(source)
    result = subprocess.run([luau, handle.name], capture_output=True, text=True)
    lines = result.stdout.strip().splitlines()
    print(f'[{label}]', lines[-1] if lines else '')
    if result.returncode != 0:
        print(result.stdout.strip())
        print(result.stderr.strip())
        return False
    return True


ok = run('kraken', bundle('kraken_check.luau'))
ok = run('behavior (native Luau)', behavior()) and ok
sys.exit(0 if ok else 1)
