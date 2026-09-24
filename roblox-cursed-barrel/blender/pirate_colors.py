"""Slot colours for the ghost pirate - mirrors PIRATE_STYLE in PirateModel.lua."""
WHITE = (240, 236, 220)
IRON = (96, 100, 106)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def slots(skin):
    coat = skin.get("coat", (58, 132, 122))
    flesh = skin.get("skin", (176, 246, 230))
    hat = skin.get("hat", (28, 36, 42))
    accent = skin.get("accent", (240, 202, 104))
    aura = skin.get("aura", (101, 241, 211))
    dark = lerp(hat, (0, 0, 0), 0.4)
    coat_dark = lerp(coat, (0, 0, 0), 0.35)
    kelp = lerp(flesh, (40, 90, 60), 0.55)
    return {
        "Coat": (coat, "Fabric", 0), "CoatTrim": (accent, "Metal", 0), "Vest": (dark, "Fabric", 0),
        "Sash": (lerp(accent, (150, 30, 40), 0.6), "Fabric", 0), "Belt": (hat, "Leather", 0), "Buckle": (accent, "Metal", 0),
        "Epaulette": (accent, "Metal", 0), "Neck": (flesh, "SmoothPlastic", 0), "Iron": (IRON, "Metal", 0),
        "Head": (flesh, "SmoothPlastic", 0), "FaceDark": (dark, "SmoothPlastic", 0), "MouthDark": ((8, 10, 12), "SmoothPlastic", 0),
        "Eye": (accent, "Neon", 0), "Patch": (hat, "Fabric", 0), "Teeth": (WHITE, "SmoothPlastic", 0),
        "Hat": (hat, "Fabric", 0), "HatTrim": (accent, "Metal", 0), "HatSkull": (WHITE, "SmoothPlastic", 0), "Feather": (accent, "Fabric", 0),
        "Jaw": (flesh, "SmoothPlastic", 0), "JawTeeth": (WHITE, "SmoothPlastic", 0), "Beard": (kelp, "SmoothPlastic", 0.1),
        "SleeveL": (coat, "Fabric", 0), "CuffL": (accent, "Fabric", 0), "LaceL": (WHITE, "Fabric", 0.1), "Hook": (IRON, "Metal", 0),
        "SleeveR": (coat, "Fabric", 0), "CuffR": (accent, "Fabric", 0), "LaceR": (WHITE, "Fabric", 0.1), "HandR": (flesh, "Neon", 0),
        "Mist": (aura, "Neon", 0.45), "Rags": (coat_dark, "Fabric", 0.2),
        "ChefHat": (hat, "SmoothPlastic", 0), "TentacleBeard": (lerp(flesh, (0, 0, 0), 0.2), "SmoothPlastic", 0),
        "VoidCrown": (accent, "Metal", 0), "FlameCrown": (aura, "Neon", 0.1), "FinCrown": (accent, "SmoothPlastic", 0),
        "DragonHorns": (accent, "Metal", 0),
    }
