-- 자동 생성 파일 (tools/blender/build_models.py). 손으로 고치지 마세요.
-- Blender 로 만든 3D 모델 조각의 크기와 자리 (Roblox 좌표 · 스터드).
-- world = true 인 조각은 월드 좌표 그대로 놓는다 (갑판에 누운 크라켄 다리).
return {
	File = "CursedBarrelModels",
	Digest = "9b8d1b45d948",
	Pieces = {
		CB_Cannon_Bore = { center = Vector3.new(1.9700, 0.0000, 0.0000), size = Vector3.new(1.5400, 0.8600, 0.8600), tris = 72 },
		CB_Cannon_Carriage = { center = Vector3.new(-0.4750, -0.9000, 0.0000), size = Vector3.new(4.7900, 1.9600, 2.7200), tris = 1844 },
		CB_Cannon_Iron = { center = Vector3.new(-0.1800, -0.9425, 0.0000), size = Vector3.new(4.5300, 2.5850, 3.5400), tris = 2456 },
		CB_Cannon_Trucks = { center = Vector3.new(-0.1800, -1.6000, 0.0000), size = Vector3.new(4.4600, 1.2000, 3.3400), tris = 1792 },
		CB_Cannon_Tube = { center = Vector3.new(-0.4650, 0.0700, -0.0000), size = Vector3.new(6.5500, 2.0900, 2.6800), tris = 4114 },
		CB_Cask_Hoops = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(3.6156, 3.6400, 3.6200), tris = 5120 },
		CB_Cask_Staves = { center = Vector3.new(0.0035, 0.0000, 0.0013), size = Vector3.new(3.6341, 4.0000, 3.6209), tris = 5468 },
		CB_Drum_Rings = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(3.7000, 4.0827, 3.7000), tris = 3072 },
		CB_Drum_Shell = { center = Vector3.new(0.0000, -0.0125, 0.0000), size = Vector3.new(3.5440, 3.9750, 3.5440), tris = 9840 },
		CB_KrakenRest_Port_Quarter_Belly = { center = Vector3.new(-58.6292, 8.4769, -138.8412), size = Vector3.new(59.6973, 41.3548, 7.9006), tris = 3980, world = true },
		CB_KrakenRest_Port_Quarter_Skin = { center = Vector3.new(-58.6292, 8.4769, -138.8412), size = Vector3.new(59.6973, 41.3548, 7.9006), tris = 7990, world = true },
		CB_KrakenRest_Port_Quarter_Suckers = { center = Vector3.new(-52.0352, 11.4174, -138.0402), size = Vector3.new(46.7270, 27.9770, 4.6472), tris = 9792, world = true },
		CB_KrakenRest_Starboard_Deck_Belly = { center = Vector3.new(66.6350, -0.8541, 49.1931), size = Vector3.new(31.5990, 22.9370, 35.8607), tris = 3980, world = true },
		CB_KrakenRest_Starboard_Deck_Skin = { center = Vector3.new(66.6350, -0.8541, 49.1931), size = Vector3.new(31.5990, 22.9370, 35.8607), tris = 7990, world = true },
		CB_KrakenRest_Starboard_Deck_Suckers = { center = Vector3.new(60.8586, 2.0843, 45.3921), size = Vector3.new(19.2026, 10.2957, 28.4504), tris = 7488, world = true },
		CB_KrakenRest_Starboard_Quarter_Belly = { center = Vector3.new(58.6582, 8.4712, -132.3838), size = Vector3.new(59.7824, 41.4486, 8.6687), tris = 3980, world = true },
		CB_KrakenRest_Starboard_Quarter_Skin = { center = Vector3.new(58.6582, 8.4712, -132.3838), size = Vector3.new(59.7824, 41.4486, 8.6687), tris = 7990, world = true },
		CB_KrakenRest_Starboard_Quarter_Suckers = { center = Vector3.new(51.9072, 11.5057, -133.3432), size = Vector3.new(46.5053, 27.7078, 4.9734), tris = 9600, world = true },
		CB_Kraken_Mantle = { center = Vector3.new(-0.5738, 4.8047, 1.2208), size = Vector3.new(48.1363, 49.4972, 50.9435), tris = 8800 },
		CB_Kraken_Segment = { center = Vector3.new(0.0000, 0.0000, -0.0038), size = Vector3.new(1.0000, 1.0352, 1.0245), tris = 352 },
		CB_Kraken_Sucker = { center = Vector3.new(0.1075, 0.0000, 0.0000), size = Vector3.new(0.2150, 1.0000, 0.9848), tris = 288 },
	},
	Assets = {
		Cannon = { "CB_Cannon_Tube", "CB_Cannon_Bore", "CB_Cannon_Carriage", "CB_Cannon_Trucks", "CB_Cannon_Iron" },
		Cask = { "CB_Cask_Staves", "CB_Cask_Hoops" },
		Drum = { "CB_Drum_Shell", "CB_Drum_Rings" },
		KrakenPieces = { "CB_Kraken_Segment", "CB_Kraken_Sucker", "CB_Kraken_Mantle" },
		Rest_Port_Quarter = { "CB_KrakenRest_Port_Quarter_Skin", "CB_KrakenRest_Port_Quarter_Belly", "CB_KrakenRest_Port_Quarter_Suckers" },
		Rest_Starboard_Deck = { "CB_KrakenRest_Starboard_Deck_Skin", "CB_KrakenRest_Starboard_Deck_Belly", "CB_KrakenRest_Starboard_Deck_Suckers" },
		Rest_Starboard_Quarter = { "CB_KrakenRest_Starboard_Quarter_Skin", "CB_KrakenRest_Starboard_Quarter_Belly", "CB_KrakenRest_Starboard_Quarter_Suckers" },
	},
}
