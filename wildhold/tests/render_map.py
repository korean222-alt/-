"""헤드리스 테스트가 내보낸 지도 격자(tests/.map_grid.txt)를 PNG 로 그린다 (게임 속 미니맵과 같은 색).
python3 tests/render_map.py [출력 폴더]  →  map_full.png (맵 전체), map_explored.png (테스트에서 가 본 곳만 = 게임 화면처럼)
색은 src/client/Controllers/MapController.lua 의 PALETTE 와 같다.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "renders")
PX = 6  # 한 칸 = 6 픽셀 (미니맵과 같은 배율)
PALETTE = {
    "G": ["#74814f"], "A": ["#56673f"], "C": ["#8b8577"], "S": ["#57634a"], "O": ["#2c4331", "#243a29"],
    "H": ["#6f6c66"], "D": ["#76664f"], "R": ["#9d9d97", "#8b8b86"], "T": ["#36532f", "#2d4729"], "Q": ["#6fe3ef"],
    "P": ["#a5885b"], "W": ["#4a7a99"], "B": ["#a8916a"], "U": ["#4d3663"], "K": ["#5a4232"], "X": ["#43301f"],
}
PAPER = "#d9c89d"


def rgb(h):
    return bytes(int(h[i:i + 2], 16) for i in (1, 3, 5))


def png(path, width, height, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def draw(grid, n, seen, path):
    rows = []
    for iz in range(n):
        row = bytearray()
        for ix in range(n):
            i = iz * n + ix
            key = grid[i]
            colors = PALETTE.get(key)
            if colors is None or (seen is not None and seen[i] != "1"):
                color = rgb(PAPER)
            else:
                color = rgb(colors[1] if len(colors) > 1 and (ix * 7 + iz * 13) % 3 == 0 else colors[0])
            row += color * PX
        for _ in range(PX):
            rows.append(bytes(row))
    png(path, n * PX, n * PX, rows)


def main():
    grid, seen = open(os.path.join(HERE, ".map_grid.txt")).read().split("\n")[:2]
    n = int(len(grid) ** 0.5)
    os.makedirs(OUT, exist_ok=True)
    draw(grid, n, None, os.path.join(OUT, "map_full.png"))
    draw(grid, n, seen, os.path.join(OUT, "map_explored.png"))
    print(f"{n}x{n} 칸 · 가 본 칸 {seen.count('1')} → {OUT}")


main()
