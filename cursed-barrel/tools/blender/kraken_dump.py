"""Run KrakenLayout (Luau) and return the resting-arm curves as Python data.
Blender(build_models.py) 와 검사가 같은 곡선을 쓰도록 Luau 실행 결과를 그대로 읽는다."""
from pathlib import Path
import json, os, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / 'game/ReplicatedStorage/CursedBarrel/Shared'


def luau_path():
    for candidate in (os.environ.get('LUAU'), shutil.which('luau'), '/opt/luau/luau'):
        if candidate and Path(candidate).exists():
            return candidate
    raise SystemExit('luau executable not found (set LUAU=/path/to/luau)')


def load():
    source = (ROOT / 'tests/run_luau.py').read_text()
    prelude = source.split("PRELUDE = r'''")[1].split("'''")[0]
    parts = [prelude]
    for name in ('ShipLayout', 'KrakenLayout'):
        parts.append(f'MODULES.{name} = function()\n{(SHARED / (name + ".lua")).read_text()}\nend\n')
    parts.append((ROOT / 'tools/blender/dump_kraken.luau').read_text())
    with tempfile.NamedTemporaryFile('w', suffix='.luau', delete=False) as handle:
        handle.write('\n'.join(parts))
    result = subprocess.run([luau_path(), handle.name], capture_output=True, text=True)
    os.unlink(handle.name)
    if result.returncode != 0:
        raise SystemExit(result.stdout + result.stderr)
    return json.loads(result.stdout)


if __name__ == '__main__':
    data = load()
    for arm in data['resting']:
        s = arm['samples']
        print(arm['name'], len(s))
        for i in range(0, len(s), 8):
            x = s[i]
            print('  %3d u=%.2f p=(%.1f,%.1f,%.1f) r=%.2f inner=(%.2f,%.2f,%.2f)' % (i, x['u'], *x['p'], x['r'], *x['inner']))
