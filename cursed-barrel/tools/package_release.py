"""출시 묶음 ZIP. 사용자 이미지 원본만 넣는다. (생성한 홍보 이미지는 넣지 않는다)

    python tools/package_release.py
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
PLACE = 'output/CursedBarrel_Phase15_Kraken.rbxl'

files = list((root / 'game').rglob('*.lua')) + list((root / 'docs').rglob('*.md'))
files += list((root / 'assets/audio').glob('*.wav'))
files += [root / 'assets/models/CursedBarrelModels.fbx'] + list((root / 'tools/blender').glob('*.py')) + list((root / 'tools/blender').glob('*.luau'))
files += [root / 'assets/branding' / n for n in ('game_profile.jpeg', 'game_thumbnail.jpeg', 'shop_button.jpeg', 'BRANDING_SETUP.md')]
files += [root / 'tools' / n for n in ('place.py', 'extend_place.py', 'generate_audio.py', 'package_release.py', 'sourcemap.py')]
files += [root / 'tests' / n for n in ('run.py', 'run_luau.py', 'behavior.lua', 'kraken_check.luau', 'verify_place.py',
                                       'StudioSmoke.server.lua', 'results.json')]
files += [root / 'base/CursedBarrel_Phase8.rbxl', root / PLACE]

destination = root / 'output/CursedBarrel_Phase15_Source.zip'
with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(root).as_posix())
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert not any(n.endswith(('.png', '.svg')) for n in archive.namelist())
    print(f'{destination}: {len(archive.namelist())} files; {destination.stat().st_size} bytes; ZIP CRC PASS')
