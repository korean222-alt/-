"""
art/out 의 카드 · 아이콘을 Roblox 에 올릴 묶음 그림으로 모은다 (Roblox 이미지는 한 장에 1024 픽셀까지).
  cards_1.png · cards_2.png · cards_3.png : 카드 여섯 장씩 (칸 300 x 510, 3열 2줄 = 900 x 1020)
  icons.png : 아이콘 여덟 개 (칸 256 x 256, 4열 2줄 = 1024 x 512)
칸 순서는 ReplicatedStorage/CursedBarrel/Shared/ArtAtlas 의 표와 같아야 한다.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CARDS = ["gold", "sleepy", "storm", "twins", "ghosts", "hooks", "greed", "lucky", "blades", "brave", "drift", "hurry", "calm", "back"]
ICONS = ["normal", "twin", "side", "skull", "mash", "angry", "lifebuoy", "lock"]
out = os.path.join(HERE, "sheets")
os.makedirs(out, exist_ok=True)

for sheet in range(3):
    img = Image.new("RGBA", (900, 1020), (0, 0, 0, 0))
    for slot, card in enumerate(CARDS[sheet * 6:sheet * 6 + 6]):
        img.alpha_composite(Image.open(os.path.join(HERE, "out", "cards", card + ".png")), ((slot % 3) * 300, (slot // 3) * 510))
    img.save(os.path.join(out, "cards_%d.png" % (sheet + 1)))

img = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
for slot, icon in enumerate(ICONS):
    img.alpha_composite(Image.open(os.path.join(HERE, "out", "icons", icon + ".png")), ((slot % 4) * 256, (slot // 4) * 256))
img.save(os.path.join(out, "icons.png"))
print("sheets:", sorted(os.listdir(out)))
