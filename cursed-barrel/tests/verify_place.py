"""Verify binary/source preservation, then run offline checks. No Roblox engine."""
from pathlib import Path
import sys, json, hashlib, subprocess, re, os, shutil
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools'))
from place import Place, u32, string

def verify(source, destination):
    before, after = Place(source), Place(destination)
    assert u32(after.header, 20) == len(after.nodes)
    for ref, node in before.nodes.items():
        assert after.nodes[ref]['class'] == node['class']
        assert before.path(ref) == after.path(ref)
    for node in after.nodes.values():
        assert node.get('parent', -1) == -1 or node['parent'] in after.nodes
    def properties(place):
        result = {}
        for tag, data, raw in place.chunks:
            if tag != b'PROP': continue
            cid = u32(data); name, _ = string(data, 4)
            if name in (b'Source', b'Name', b'StreamingEnabled'): continue
            result[(cid, name)] = raw
        return result
    assert properties(before) == properties(after), 'Unrelated instance properties changed'
    count = 0
    for ref, node in after.nodes.items():
        if 'Source' not in node: continue
        suffix = {'Script': '.server.lua', 'LocalScript': '.client.lua', 'ModuleScript': '.lua'}[node['class']]
        assert node['Source'] == (root / 'game' / (after.path(ref) + suffix)).read_text()
        count += 1
    assert count == len(list((root / 'game').rglob('*.lua')))
    result = subprocess.run([sys.executable, str(root / 'tests/run.py')], capture_output=True, text=True)
    print(result.stdout)
    assert result.returncode == 0, result.stderr
    checks = int(re.search(r'BEHAVIOR CHECKS: (\d+) passed', result.stdout)[1])

    # Luau 로 직접 돌리는 검사 (luau 실행 파일이 있을 때). 문법 컴파일 · 크라켄 배치 · 같은 동작 검사.
    luau = os.environ.get('LUAU') or shutil.which('luau')
    native = 'NOT_RUN (luau executable not found)'
    compiled = 'NOT_RUN'
    if luau:
        compiler = os.environ.get('LUAU_COMPILE') or str(Path(luau).with_name('luau-compile'))
        if Path(compiler).exists():
            files = [str(f) for f in sorted((root / 'game').rglob('*.lua'))]
            done = subprocess.run([compiler, '--null', *files], capture_output=True, text=True)
            assert done.returncode == 0, done.stderr
            compiled = f'PASS ({len(files)} files, luau-compile)'
        luau_run = subprocess.run([sys.executable, str(root / 'tests/run_luau.py'), luau], capture_output=True, text=True)
        print(luau_run.stdout)
        assert luau_run.returncode == 0, luau_run.stdout + luau_run.stderr
        native = luau_run.stdout.strip().splitlines()
    report = {
        'place': Path(destination).name,
        'sha256': hashlib.sha256(Path(destination).read_bytes()).hexdigest(),
        'original_instances': len(before.nodes), 'output_instances': len(after.nodes),
        'source_files': count, 'behavior_checks_passed': checks,
        'unrelated_binary_properties': 'PRESERVED', 'source_roundtrip': 'PASS',
        'parser': 'Lua 5.4 after simple compound-assignment translation (tests/run.py)',
        'luau_compile': compiled,
        'native_luau_checks': native,
        'roblox_studio_open': 'NOT_RUN', 'multiplayer_device_physics_QA': 'NOT_RUN',
        'live_datastore_receipts_assets': 'NOT_RUN', 'test_output': result.stdout.splitlines(),
    }
    (root / 'tests/results.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'test_output'}, indent=2))

if __name__ == '__main__':
    verify(*sys.argv[1:])
