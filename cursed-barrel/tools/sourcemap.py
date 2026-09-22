"""Rojo 형식 sourcemap.json 을 game/ 폴더에서 만든다.

luau-lsp 가 `script.Parent.X` 와 `ReplicatedStorage.CursedBarrel...` 경로를 따라가
Roblox 타입 검사를 할 수 있게 하려는 용도다. 게임 동작에는 영향이 없다.

    python tools/sourcemap.py > sourcemap.json
    luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json game
"""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
game = root / 'game'

SERVICE_CLASS = {
    'ReplicatedStorage': 'ReplicatedStorage',
    'ServerScriptService': 'ServerScriptService',
    'StarterPlayer': 'StarterPlayer',
    'StarterPlayerScripts': 'StarterPlayerScripts',
}
SUFFIX = [('.server.lua', 'Script'), ('.client.lua', 'LocalScript'), ('.lua', 'ModuleScript')]

# .rbxl 안에만 있고 소스 폴더에는 없는 인스턴스. 타입 검사가 경로를 따라갈 수 있게 알려 준다.
EXTRA = {
    ('ReplicatedStorage', 'CursedBarrel'): [
        {'name': 'Remotes', 'className': 'Folder', 'children': [
            {'name': n, 'className': 'RemoteEvent'} for n in (
                'SelectSlot', 'PresentationCue', 'CatchPrompt', 'CatchInput', 'CatchResult', 'EquipSkin',
                'ShopRequest', 'ShopResult', 'Sabotage', 'SabotageCue', 'QuestUpdate')
        ]},
        {'name': 'Visuals', 'className': 'Folder', 'children': [
            {'name': 'GhostCaptain', 'className': 'Model'},
        ]},
    ],
}


def node(path, parts):
    if path.is_file():
        for suffix, cls in SUFFIX:
            if path.name.endswith(suffix):
                return {'name': path.name[:-len(suffix)], 'className': cls,
                        'filePaths': [path.relative_to(root).as_posix()]}
        return None
    cls = SERVICE_CLASS.get(path.name, 'Folder') if len(parts) <= 2 else 'Folder'
    children = [c for c in (node(p, parts + (p.name,)) for p in sorted(path.iterdir())) if c]
    children += EXTRA.get(parts, [])
    return {'name': path.name, 'className': cls, 'children': children}


tree = {'name': 'Game', 'className': 'DataModel',
        'children': [node(p, (p.name,)) for p in sorted(game.iterdir())]}
print(json.dumps(tree, ensure_ascii=False, indent=1))
