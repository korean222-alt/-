"""Curated release archive. User images only; no generated promotional art."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).resolve().parents[1]
files = list((root / 'game').rglob('*.lua')) + list((root / 'docs').rglob('*.md'))
files += list((root / 'assets/audio').glob('*.wav'))
files += [root / 'assets/branding' / n for n in ('game_profile.jpeg', 'game_thumbnail.jpeg', 'shop_button.jpeg', 'BRANDING_SETUP.md')]
files += [root / 'tools' / n for n in ('place.py', 'extend_place.py', 'generate_audio.py', 'package_release.py')]
files += [root / 'tests' / n for n in ('run.py', 'behavior.lua', 'verify_place.py', 'StudioSmoke.server.lua', 'results.json')]
files += [root / 'output/Phase9_Review_KO.md', root / 'output/CursedBarrel_Phase9_DragonTide.rbxl']
destination = root / 'output/CursedBarrel_Phase9_Source.zip'
with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(root).as_posix())
    archive.write(root / 'upload/CursedBarrel_Phase8.rbxl', 'base/CursedBarrel_Phase8.rbxl')
    for path in (root / 'upload').glob('*.md'):
        archive.write(path, 'docs/reference/' + path.name)
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert not any(n.endswith(('.png', '.svg')) for n in archive.namelist())
    print(f'{destination}: {len(archive.namelist())} files; {destination.stat().st_size} bytes; ZIP CRC PASS')
