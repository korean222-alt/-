--[[
	MeshKit  (Phase 15)
	Blender 로 만든 3D 모델을 게임에 놓는다.

	모델 파일 : assets/models/CursedBarrelModels.fbx (tools/blender/build_models.py 가 만든다)
	넣는 법   : Studio → 홈 → 3D 가져오기 → 그 파일 → 가져오기. 그리고 저장(Publish).
	            CB_ 로 시작하는 MeshPart 가 가득 든 모델이 Workspace 에 생긴다. 그대로 두면 된다.
	            (서버가 켜질 때 ReplicatedStorage 로 옮겨 보이지 않는 보관함으로 쓴다: MeshKit.adopt)

	· 조각마다 크기 · 자리는 MeshCatalog(자동 생성)에 있다. 가져오기 창의 단위 설정이 무엇이든
	  Size · CFrame 을 그 값으로 다시 맞추므로 제자리 · 제 크기에 놓인다.
	· 모델을 아직 안 넣었으면 모든 함수가 nil / false 를 돌려준다. 부르는 쪽은 예전(파트로 만든) 모양을 그대로 쓴다.
	  그래서 모델이 없어도 게임은 똑같이 돌아간다.
	· 색 · 재질은 부르는 쪽이 정한다 (통 스킨 색, 크라켄 색 …). 가져온 텍스처 · SurfaceAppearance 는 떼어 낸다.

	Phase 17 : 스킨 모델 파일이 하나 더 생겼다.
	  assets/models/CursedBarrelSkins.fbx (roblox-cursed-barrel/blender/build_all.py 가 만든다)
	  칼 7모양 · 통 장식 6종 · 해적 한 벌(+테마 장식 6) · 용 2종 · 꽃잎 · 룬 고리 · 크라켄 마디. SK_ 로 시작한다.
	  가져오는 법은 같다 (3D 가져오기 · "단일 메시로 가져오기" 끄기). 두 파일 모두 서버가 켜질 때 ReplicatedStorage 로 옮긴다.
	  크기 · 자리는 SkinMeshCatalog(자동 생성)에 있고 MeshCatalog 와 합쳐서 쓴다.

	Phase 24.12 : 배 소품 모델 파일이 하나 더 생겼다.
	  CursedBarrelProps.fbx (props/build_props.py 가 만든다). 계단 · 난간 · 짐 상자 · 등불 · 등불 기둥 · 화물 창 ·
	  권양기 · 조타륜 · 돛 · 망대 · 게임 테이블 · 의자 · 전시대. PR_ 로 시작한다.
	  가져오는 법은 같다 (3D 가져오기 · "단일 메시로 가져오기" 끄기). 크기 · 자리는 아래 PropCatalog 에 있다.
	  가져오기 전에는 MeshKit.has 가 false 라서 예전(파트) 모양이 그대로 나온다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseCatalog = require(script.Parent:WaitForChild("MeshCatalog"))
local SkinCatalog = require(script.Parent:WaitForChild("SkinMeshCatalog"))

-- 자동 생성 (props/build_props.py). 손으로 고치지 마세요.
-- Phase 24.12 : 배 소품 Blender 모델 (CursedBarrelProps.fbx) 조각의 크기와 자리 (Roblox 좌표 · 스터드).
local PropCatalog = {
	File = "CursedBarrelProps",
	Digest = "e95900b21f12",
	Pieces = {
		PR_ArchBeam_Brass = { center = Vector3.new(0.0000, 0.2600, 0.0000), size = Vector3.new(10.3000, 0.8000, 1.3863), tris = 268 },
		PR_ArchBeam_Wood = { center = Vector3.new(0.0000, 0.0075, 0.0000), size = Vector3.new(10.3000, 1.1350, 1.3000), tris = 132 },
		PR_Arch_Iron = { center = Vector3.new(0.0000, 10.8960, 0.0000), size = Vector3.new(23.8500, 1.0079, 0.8000), tris = 488 },
		PR_Arch_Wood = { center = Vector3.new(0.0000, 5.8375, 0.0000), size = Vector3.new(26.1110, 11.6750, 1.3000), tris = 1144 },
		PR_Board10_Brass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(10.8804, 10.1000, 1.3618), tris = 1072 },
		PR_Board10_Frame = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(11.4000, 10.5000, 0.9500), tris = 440 },
		PR_Board10_Planks = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(9.9400, 9.2000, 0.4000), tris = 264 },
		PR_Board13_Brass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(14.4804, 9.3000, 1.3618), tris = 1072 },
		PR_Board13_Frame = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(15.0000, 9.7000, 0.9500), tris = 440 },
		PR_Board13_Planks = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(13.5400, 8.4000, 0.4000), tris = 396 },
		PR_Board9_Brass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(9.8804, 9.3000, 1.3618), tris = 1072 },
		PR_Board9_Frame = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(10.4000, 9.7000, 0.9500), tris = 440 },
		PR_Board9_Planks = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(8.9400, 8.4000, 0.4000), tris = 308 },
		PR_Bowsprit_Iron = { center = Vector3.new(0.0000, 0.2917, -20.2701), size = Vector3.new(1.6332, 2.2166, 28.1839), tris = 1324 },
		PR_Bowsprit_Wood = { center = Vector3.new(0.0000, 0.2300, -24.8000), size = Vector3.new(1.5204, 2.0195, 53.6000), tris = 240 },
		PR_Bulwark_Brass = { center = Vector3.new(0.6400, 3.3600, 0.0000), size = Vector3.new(0.0400, 0.0800, 5.9712), tris = 12 },
		PR_Bulwark_Cap = { center = Vector3.new(-0.0225, 1.6100, 0.0000), size = Vector3.new(1.2950, 3.9200, 5.9712), tris = 132 },
		PR_Bulwark_Planks = { center = Vector3.new(0.0000, 1.2350, 0.0000), size = Vector3.new(0.8200, 3.9700, 5.9612), tris = 396 },
		PR_CabinFront_Brass = { center = Vector3.new(0.0000, 13.7800, 0.4995), size = Vector3.new(104.5000, 2.4600, 0.4609), tris = 328 },
		PR_CabinFront_DarkWood = { center = Vector3.new(0.0000, 10.7500, 0.3400), size = Vector3.new(104.0000, 9.5000, 0.6800), tris = 968 },
		PR_CabinFront_Wood = { center = Vector3.new(0.0000, 8.0000, 0.5000), size = Vector3.new(105.0000, 16.0000, 1.3029), tris = 10648 },
		PR_CabinPanel_Brass = { center = Vector3.new(0.0000, 4.0800, 0.2900), size = Vector3.new(13.0000, 0.0600, 0.0300), tris = 12 },
		PR_CabinPanel_DarkWood = { center = Vector3.new(0.0000, 2.2000, 0.0500), size = Vector3.new(12.7000, 2.8000, 0.1000), tris = 132 },
		PR_CabinPanel_Wood = { center = Vector3.new(0.0000, 7.9825, 0.2825), size = Vector3.new(13.0700, 16.0350, 0.6350), tris = 1372 },
		PR_Capstan_Iron = { center = Vector3.new(0.0000, 1.3900, 0.0000), size = Vector3.new(4.4000, 2.7800, 3.8507), tris = 1924 },
		PR_Capstan_Wood = { center = Vector3.new(0.0000, 1.3600, 0.0000), size = Vector3.new(5.2553, 2.7200, 5.2553), tris = 1670 },
		PR_Chair_Brass = { center = Vector3.new(0.0000, 2.5375, 1.0267), size = Vector3.new(2.2200, 0.6850, 0.1846), tris = 456 },
		PR_Chair_Cushion = { center = Vector3.new(0.0000, 0.3300, -0.0800), size = Vector3.new(1.9500, 0.1600, 1.8500), tris = 88 },
		PR_Chair_Wood = { center = Vector3.new(0.0000, 0.3000, 0.0272), size = Vector3.new(2.3000, 4.6000, 2.3957), tris = 3908 },
		PR_Crate_DarkWood = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(3.4200, 3.2700, 3.2800), tris = 708 },
		PR_Crate_Iron = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(3.2800, 3.2800, 4.7949), tris = 2168 },
		PR_Crate_Planks = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(3.1800, 3.1800, 3.1800), tris = 1056 },
		PR_Crate_Rope = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.6212, 3.5000, 4.4247), tris = 176 },
		PR_CrowsNest_DarkWood = { center = Vector3.new(0.0000, -0.5500, 0.0000), size = Vector3.new(7.8000, 0.4000, 7.8000), tris = 176 },
		PR_CrowsNest_Iron = { center = Vector3.new(0.0000, 0.1543, 0.0000), size = Vector3.new(8.3250, 0.4299, 8.3250), tris = 1344 },
		PR_CrowsNest_Wood = { center = Vector3.new(0.0000, 1.0900, 0.0000), size = Vector3.new(8.1600, 2.7400, 8.1600), tris = 3760 },
		PR_Deadeye_Iron = { center = Vector3.new(0.0000, -0.8938, 0.0000), size = Vector3.new(0.1200, 3.8125, 0.9249), tris = 428 },
		PR_Deadeye_Rope = { center = Vector3.new(0.0000, 1.0500, 0.0033), size = Vector3.new(0.0666, 0.7000, 0.4233), tris = 48 },
		PR_Deadeye_Wood = { center = Vector3.new(0.0000, 1.0500, 0.0000), size = Vector3.new(0.3000, 1.7600, 0.7409), tris = 336 },
		PR_FXCoin_Gold = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.0000, 1.0000, 0.3933), tris = 640 },
		PR_FXCrown_Gem = { center = Vector3.new(0.0000, 0.6250, 0.0000), size = Vector3.new(1.5190, 0.9700, 1.5190), tris = 768 },
		PR_FXCrown_Gold = { center = Vector3.new(0.0000, 0.4590, 0.0000), size = Vector3.new(1.5238, 0.9820, 1.5238), tris = 944 },
		PR_FXFeather_Feather = { center = Vector3.new(0.0000, 0.0052, 0.0704), size = Vector3.new(0.6650, 1.2221, 0.1791), tris = 236 },
		PR_FXRing_Ring = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.0000, 0.0800, 2.0000), tris = 480 },
		PR_FXRune_Crystal = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(0.4000, 1.1000, 0.3464), tris = 24 },
		PR_FXSkull_Bone = { center = Vector3.new(0.0000, 0.0400, 0.0000), size = Vector3.new(1.0000, 1.2200, 1.0000), tris = 312 },
		PR_FXSkull_Dark = { center = Vector3.new(0.0000, -0.1550, -0.3600), size = Vector3.new(0.6200, 0.6700, 0.2473), tris = 264 },
		PR_FXStar_Star = { center = Vector3.new(0.0000, 0.0477, 0.0000), size = Vector3.new(0.9511, 0.9045, 0.2800), tris = 40 },
		PR_GunPort_Dark = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(0.8900, 1.7000, 1.7000), tris = 24 },
		PR_GunPort_Iron = { center = Vector3.new(0.5500, 1.0600, 0.0000), size = Vector3.new(0.1200, 0.1200, 1.2000), tris = 88 },
		PR_GunPort_Wood = { center = Vector3.new(0.8702, 0.4042, 0.0000), size = Vector3.new(2.8004, 2.9284, 2.2000), tris = 396 },
		PR_Hatch_Dark = { center = Vector3.new(0.0000, 0.0200, 0.0000), size = Vector3.new(7.8000, 0.0400, 5.8000), tris = 12 },
		PR_Hatch_Iron = { center = Vector3.new(0.0000, 0.2225, 0.0000), size = Vector3.new(9.1000, 0.4050, 7.1000), tris = 1024 },
		PR_Hatch_Wood = { center = Vector3.new(0.0000, 0.2000, 0.0000), size = Vector3.new(9.0000, 0.4000, 7.0000), tris = 1320 },
		PR_Helm_Brass = { center = Vector3.new(0.0000, 0.0000, -0.3420), size = Vector3.new(4.7964, 4.7964, 0.4453), tris = 428 },
		PR_Helm_Stand = { center = Vector3.new(0.0000, -1.4250, 0.7000), size = Vector3.new(1.5000, 3.5500, 1.6000), tris = 416 },
		PR_Helm_Wheel = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(7.2000, 7.2000, 0.6400), tris = 3788 },
		PR_HullSide_Brass = { center = Vector3.new(57.3450, -0.3000, 0.0000), size = Vector3.new(0.0800, 0.1800, 5.9812), tris = 12 },
		PR_HullSide_Planks = { center = Vector3.new(47.3307, -6.4604, 0.0000), size = Vector3.new(20.5916, 13.2480, 5.9612), tris = 616 },
		PR_HullSide_Wale = { center = Vector3.new(56.2575, -2.8500, 0.0000), size = Vector3.new(2.0150, 3.6500, 5.9812), tris = 88 },
		PR_LampPost_Iron = { center = Vector3.new(0.0000, 1.6125, 0.0000), size = Vector3.new(1.0000, 3.2250, 1.0000), tris = 424 },
		PR_LampPost_Wood = { center = Vector3.new(0.0000, 1.6000, 0.0000), size = Vector3.new(0.8000, 3.2000, 0.8000), tris = 440 },
		PR_Lantern_Glass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(0.8200, 1.0800, 0.8200), tris = 12 },
		PR_Lantern_Iron = { center = Vector3.new(0.0000, 0.3913, 0.0000), size = Vector3.new(1.1031, 2.3225, 1.1031), tris = 1434 },
		PR_Mast_Iron = { center = Vector3.new(0.0000, 27.9543, 0.0000), size = Vector3.new(4.5449, 54.2472, 4.5449), tris = 4992 },
		PR_Mast_Rail = { center = Vector3.new(0.0000, 1.7800, 0.0000), size = Vector3.new(6.3000, 3.5600, 6.3000), tris = 3664 },
		PR_Mast_Wood = { center = Vector3.new(0.0000, 30.8000, 0.0000), size = Vector3.new(4.2358, 61.6000, 4.2358), tris = 568 },
		PR_Pedestal_Brass = { center = Vector3.new(0.0000, 1.3400, 0.0000), size = Vector3.new(6.3000, 1.9066, 6.3000), tris = 960 },
		PR_Pedestal_Stone = { center = Vector3.new(0.0000, 1.3000, 0.0000), size = Vector3.new(6.5000, 2.6000, 6.5000), tris = 2062 },
		PR_Post_Brass = { center = Vector3.new(0.0000, 10.4640, 0.0000), size = Vector3.new(1.0000, 0.9280, 1.0000), tris = 180 },
		PR_Post_Iron = { center = Vector3.new(0.0000, 5.2000, 0.0000), size = Vector3.new(0.9800, 7.3600, 0.9800), tris = 88 },
		PR_Post_Wood = { center = Vector3.new(0.0000, 5.1000, 0.0000), size = Vector3.new(1.3000, 10.2000, 1.3000), tris = 176 },
		PR_Rail16_Brass = { center = Vector3.new(0.0000, 2.9900, 0.0071), size = Vector3.new(0.3300, 0.4800, 16.2996), tris = 414 },
		PR_Rail16_Wood = { center = Vector3.new(0.0000, 1.3900, 0.0125), size = Vector3.new(0.6100, 2.7800, 16.5850), tris = 6192 },
		PR_Rail4_Brass = { center = Vector3.new(0.0000, 2.9900, 0.0071), size = Vector3.new(0.3300, 0.4800, 4.2996), tris = 276 },
		PR_Rail4_Wood = { center = Vector3.new(0.0000, 1.3900, 0.0125), size = Vector3.new(0.6100, 2.7800, 4.5850), tris = 1576 },
		PR_RailLamp_Iron = { center = Vector3.new(-0.7750, 1.8825, 0.0000), size = Vector3.new(1.5500, 1.1349, 0.0800), tris = 432 },
		PR_RailLamp_Wood = { center = Vector3.new(0.0000, 1.3000, 0.0000), size = Vector3.new(0.5000, 2.6000, 0.5000), tris = 182 },
		PR_RailPost_Iron = { center = Vector3.new(0.0000, 1.9000, 0.0000), size = Vector3.new(1.2800, 2.9200, 1.2800), tris = 88 },
		PR_RailPost_Wood = { center = Vector3.new(0.0000, 2.2000, 0.0000), size = Vector3.new(1.8000, 4.4000, 1.2000), tris = 278 },
		PR_Sail_Cloth = { center = Vector3.new(0.0000, 5.8500, 1.7256), size = Vector3.new(46.8000, 10.8000, 3.4288), tris = 1184 },
		PR_Sail_Iron = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(32.0855, 0.8222, 0.8222), tris = 1004 },
		PR_Sail_Rope = { center = Vector3.new(0.0000, 5.8461, 1.4870), size = Vector3.new(46.8846, 10.9521, 3.0316), tris = 1020 },
		PR_Sail_Seam = { center = Vector3.new(0.0000, 5.8500, 1.8155), size = Vector3.new(35.2403, 10.8206, 3.3388), tris = 1680 },
		PR_Sail_Yard = { center = Vector3.new(0.0000, 5.6350, 0.1838), size = Vector3.new(47.4000, 11.9900, 1.0524), tris = 176 },
		PR_SignBar_Brass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(10.0000, 0.0500, 0.5700), tris = 24 },
		PR_SignBar_Wood = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(10.1000, 0.5000, 0.6000), tris = 132 },
		PR_SignCap_Brass = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(0.2000, 0.6000, 0.6500), tris = 24 },
		PR_SignCap_Wood = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(0.6200, 1.0000, 0.7000), tris = 132 },
		PR_StairB_Balusters = { center = Vector3.new(0.0000, 3.6656, -5.2500), size = Vector3.new(11.8125, 6.0512, 7.6840), tris = 1248 },
		PR_StairB_Brass = { center = Vector3.new(0.0000, 5.1689, -4.1900), size = Vector3.new(12.1200, 5.0045, 10.1400), tris = 600 },
		PR_StairB_DarkWood = { center = Vector3.new(0.0000, 2.1400, -4.4050), size = Vector3.new(11.9400, 4.2800, 10.9500), tris = 412 },
		PR_StairB_Wood = { center = Vector3.new(0.0000, 3.6056, -5.1700), size = Vector3.new(12.1800, 7.2112, 12.1600), tris = 1232 },
		PR_StairQ_Balusters = { center = Vector3.new(0.0000, 9.8442, -19.4400), size = Vector3.new(6.8125, 18.2883, 35.8240), tris = 4784 },
		PR_StairQ_Brass = { center = Vector3.new(0.0000, 11.3182, -18.2825), size = Vector3.new(7.1200, 17.3003, 38.4750), tris = 600 },
		PR_StairQ_DarkWood = { center = Vector3.new(0.0000, 8.3000, -18.5200), size = Vector3.new(7.2200, 16.6000, 39.3300), tris = 1688 },
		PR_StairQ_Wood = { center = Vector3.new(0.0000, 9.7542, -19.3600), size = Vector3.new(7.1800, 19.5083, 40.6900), tris = 2728 },
		PR_Stern_Balusters = { center = Vector3.new(0.0000, 5.3500, -2.5000), size = Vector3.new(92.2000, 1.7000, 0.1732), tris = 4888 },
		PR_Stern_Brass = { center = Vector3.new(0.0000, 4.4100, -1.8823), size = Vector3.new(100.5000, 13.9800, 3.3353), tris = 536 },
		PR_Stern_DarkWood = { center = Vector3.new(0.0000, 4.0000, -1.8000), size = Vector3.new(81.0000, 13.0000, 3.2800), tris = 924 },
		PR_Stern_Glass = { center = Vector3.new(0.0000, 8.0000, -0.1200), size = Vector3.new(81.0000, 5.0000, 0.1000), tris = 60 },
		PR_Stern_Wood = { center = Vector3.new(0.0000, 1.2375, -1.7500), size = Vector3.new(100.5000, 19.3750, 3.5000), tris = 2068 },
		PR_Table_Band = { center = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(9.7800, 0.2000, 9.7800), tris = 384 },
		PR_Table_Base = { center = Vector3.new(0.0000, -1.7750, 0.0000), size = Vector3.new(4.0838, 2.8700, 4.0584), tris = 1400 },
		PR_Table_Fittings = { center = Vector3.new(0.0000, -1.8590, 0.0000), size = Vector3.new(3.3478, 2.5820, 3.7282), tris = 880 },
		PR_Table_Rim = { center = Vector3.new(0.0000, -0.0500, 0.0000), size = Vector3.new(9.6800, 0.7600, 9.6800), tris = 1232 },
		PR_Table_Top = { center = Vector3.new(0.0000, 0.0350, 0.0000), size = Vector3.new(8.6000, 0.4800, 8.0650), tris = 396 },
		PR_ThroneDragon_Dark = { center = Vector3.new(0.0000, 1.2000, 0.1000), size = Vector3.new(2.9000, 6.4000, 2.9000), tris = 60 },
		PR_ThroneDragon_Frame = { center = Vector3.new(0.0000, 1.7840, -0.0449), size = Vector3.new(3.0500, 7.2679, 2.8399), tris = 1280 },
		PR_ThroneDragon_Gem = { center = Vector3.new(0.0000, 3.4400, 0.0684), size = Vector3.new(2.8663, 4.7600, 2.8031), tris = 396 },
		PR_ThroneDragon_Horns = { center = Vector3.new(0.0000, 3.4519, 1.3212), size = Vector3.new(4.2334, 5.5279, 1.9085), tris = 520 },
		PR_ThroneDragon_Panel = { center = Vector3.new(0.0000, 2.2000, 0.0075), size = Vector3.new(2.0000, 3.9000, 2.1650), tris = 88 },
		PR_Throne_Dark = { center = Vector3.new(0.0000, 1.2000, 0.1000), size = Vector3.new(2.9000, 6.4000, 2.9000), tris = 60 },
		PR_Throne_Frame = { center = Vector3.new(0.0000, 1.7840, -0.0449), size = Vector3.new(3.0500, 7.2679, 2.8399), tris = 1280 },
		PR_Throne_Gem = { center = Vector3.new(0.0000, 3.4400, 0.0684), size = Vector3.new(2.8663, 4.7600, 2.8031), tris = 396 },
		PR_Throne_Panel = { center = Vector3.new(0.0000, 2.2000, 0.0075), size = Vector3.new(2.0000, 3.9000, 2.1650), tris = 88 },
		PR_WallLamp_Iron = { center = Vector3.new(0.0000, 0.3000, 0.8750), size = Vector3.new(0.5000, 1.3000, 1.7500), tris = 476 },
	},
	Assets = {
		StairQ = { "PR_StairQ_Wood", "PR_StairQ_Balusters", "PR_StairQ_DarkWood", "PR_StairQ_Brass" },
		StairB = { "PR_StairB_Wood", "PR_StairB_Balusters", "PR_StairB_DarkWood", "PR_StairB_Brass" },
		Rail16 = { "PR_Rail16_Wood", "PR_Rail16_Brass" },
		Rail4 = { "PR_Rail4_Wood", "PR_Rail4_Brass" },
		Crate = { "PR_Crate_Planks", "PR_Crate_DarkWood", "PR_Crate_Iron", "PR_Crate_Rope" },
		Lantern = { "PR_Lantern_Iron", "PR_Lantern_Glass" },
		LampPost = { "PR_LampPost_Wood", "PR_LampPost_Iron" },
		Hatch = { "PR_Hatch_Wood", "PR_Hatch_Dark", "PR_Hatch_Iron" },
		Capstan = { "PR_Capstan_Wood", "PR_Capstan_Iron" },
		Helm = { "PR_Helm_Wheel", "PR_Helm_Brass", "PR_Helm_Stand" },
		Sail = { "PR_Sail_Cloth", "PR_Sail_Seam", "PR_Sail_Yard", "PR_Sail_Rope", "PR_Sail_Iron" },
		CrowsNest = { "PR_CrowsNest_Wood", "PR_CrowsNest_DarkWood", "PR_CrowsNest_Iron" },
		Table = { "PR_Table_Top", "PR_Table_Rim", "PR_Table_Band", "PR_Table_Base", "PR_Table_Fittings" },
		Chair = { "PR_Chair_Wood", "PR_Chair_Cushion", "PR_Chair_Brass" },
		Pedestal = { "PR_Pedestal_Stone", "PR_Pedestal_Brass" },
		Bulwark = { "PR_Bulwark_Planks", "PR_Bulwark_Cap", "PR_Bulwark_Brass" },
		RailPost = { "PR_RailPost_Wood", "PR_RailPost_Iron" },
		GunPort = { "PR_GunPort_Wood", "PR_GunPort_Dark", "PR_GunPort_Iron" },
		Mast = { "PR_Mast_Wood", "PR_Mast_Iron", "PR_Mast_Rail" },
		Arch = { "PR_Arch_Wood", "PR_Arch_Iron" },
		Bowsprit = { "PR_Bowsprit_Wood", "PR_Bowsprit_Iron" },
		RailLamp = { "PR_RailLamp_Wood", "PR_RailLamp_Iron" },
		WallLamp = { "PR_WallLamp_Iron" },
		Board9 = { "PR_Board9_Planks", "PR_Board9_Frame", "PR_Board9_Brass" },
		Board10 = { "PR_Board10_Planks", "PR_Board10_Frame", "PR_Board10_Brass" },
		Board13 = { "PR_Board13_Planks", "PR_Board13_Frame", "PR_Board13_Brass" },
		CabinFront = { "PR_CabinFront_Wood", "PR_CabinFront_DarkWood", "PR_CabinFront_Brass" },
		Throne = { "PR_Throne_Frame", "PR_Throne_Panel", "PR_Throne_Dark", "PR_Throne_Gem" },
		ThroneDragon = { "PR_ThroneDragon_Frame", "PR_ThroneDragon_Panel", "PR_ThroneDragon_Dark", "PR_ThroneDragon_Gem", "PR_ThroneDragon_Horns" },
		FXCoin = { "PR_FXCoin_Gold" },
		FXStar = { "PR_FXStar_Star" },
		FXCrown = { "PR_FXCrown_Gold", "PR_FXCrown_Gem" },
		FXRing = { "PR_FXRing_Ring" },
		FXRune = { "PR_FXRune_Crystal" },
		FXFeather = { "PR_FXFeather_Feather" },
		FXSkull = { "PR_FXSkull_Bone", "PR_FXSkull_Dark" },
		HullSide = { "PR_HullSide_Planks", "PR_HullSide_Wale", "PR_HullSide_Brass" },
		Stern = { "PR_Stern_Wood", "PR_Stern_Balusters", "PR_Stern_DarkWood", "PR_Stern_Brass", "PR_Stern_Glass" },
		CabinPanel = { "PR_CabinPanel_Wood", "PR_CabinPanel_DarkWood", "PR_CabinPanel_Brass" },
		Deadeye = { "PR_Deadeye_Iron", "PR_Deadeye_Wood", "PR_Deadeye_Rope" },
		SignBar = { "PR_SignBar_Wood", "PR_SignBar_Brass" },
		SignCap = { "PR_SignCap_Wood", "PR_SignCap_Brass" },
		Post = { "PR_Post_Wood", "PR_Post_Iron", "PR_Post_Brass" },
		ArchBeam = { "PR_ArchBeam_Wood", "PR_ArchBeam_Brass" },
	},
}


-- 두 카탈로그를 하나로 합친다 (조각 이름이 CB_ / SK_ 로 달라서 겹치지 않는다)
local Catalog = { File = BaseCatalog.File, Digest = BaseCatalog.Digest, Pieces = {}, Assets = {}, PirateJoints = SkinCatalog.PirateJoints }
for _, source in ipairs({ BaseCatalog, SkinCatalog, PropCatalog }) do
	for name, info in pairs(source.Pieces) do
		Catalog.Pieces[name] = info
	end
	for name, list in pairs(source.Assets) do
		Catalog.Assets[name] = list
	end
end

local MeshKit = {}
MeshKit.LibraryName = "CursedBarrelModels"
MeshKit.SkinLibraryName = "CursedBarrelSkins"
MeshKit.PropLibraryName = "CursedBarrelProps"
MeshKit.LibraryNames = { MeshKit.LibraryName, MeshKit.SkinLibraryName, MeshKit.PropLibraryName }
MeshKit.Catalog = Catalog

local libraries = {} -- [이름] = Model
local templates = {}

-- 파일마다 들어 있어야 하는 조각 (이것으로 어느 파일을 가져온 모델인지 알아본다)
local MARKERS = {
	CursedBarrelModels = { "CB_Cannon_Tube", "CB_Cask_Staves", "CB_Kraken_Mantle" },
	CursedBarrelSkins = { "SK_Knife_dagger_Blade", "SK_Pirate_Coat", "SK_DragonCoil_Scales" },
	CursedBarrelProps = { "PR_Crate_Planks", "PR_Lantern_Iron", "PR_Table_Top" },
}

local function isLibrary(instance, libraryName)
	if not instance or not (instance:IsA("Model") or instance:IsA("Folder")) then
		return false
	end
	for _, marker in ipairs(MARKERS[libraryName or MeshKit.LibraryName]) do
		if instance:FindFirstChild(marker, true) ~= nil then
			return true
		end
	end
	return false
end

--[[
	Phase 17.1 : 가져온 방향 바로잡기
	  Studio 3D 가져오기는 Blender 파일을 세로축(Y)으로 180° 돌려서 넣는다.
	  (가져온 조각의 자리가 카탈로그의 (-x, y, -z) 에 있다 → 메시도 조각 안에서 180° 돌아가 있다)
	  둥근 통 · 드럼은 티가 안 나지만, 누운 크라켄 다리는 살이 선실 쪽으로 뒤집히고 빨판만 2층에 떠 있었다.
	  두 조각의 가져온 자리를 카탈로그와 비교해서 파일마다 돌림을 알아내고, 놓을 때 되돌린다.
]]
local IDENTITY = CFrame.new()
local HALF_TURN = CFrame.Angles(0, math.pi, 0)
local PROBES = {
	CursedBarrelModels = { "CB_Kraken_Mantle", "CB_Cask_Hoops" },
	CursedBarrelSkins = { "SK_DragonCoil_Eyes", "SK_Kraken_Capsule" },
	CursedBarrelProps = { "PR_StairQ_Wood", "PR_Crate_Planks" }, -- 계단은 -Z 쪽으로 길게 뻗어 있어 돌림을 알아보기 쉽다
}
local fixes = {} -- [라이브러리 이름] = CFrame

local function detectFix(libraryName, root)
	local probe = PROBES[libraryName]
	local a = probe and root:FindFirstChild(probe[1], true)
	local b = probe and root:FindFirstChild(probe[2], true)
	local ia = probe and Catalog.Pieces[probe[1]]
	local ib = probe and Catalog.Pieces[probe[2]]
	if not (a and b and ia and ib and a:IsA("BasePart") and b:IsA("BasePart")) then
		return IDENTITY
	end
	local imported = b.CFrame:PointToObjectSpace(a.CFrame.Position)
	local expected = ia.center - ib.center
	local turned = Vector3.new(-expected.X, expected.Y, -expected.Z)
	if (imported - turned).Magnitude + 1e-3 < (imported - expected).Magnitude then
		return HALF_TURN
	end
	return IDENTITY
end

function MeshKit.isLibraryName(name)
	return name == MeshKit.LibraryName or name == MeshKit.SkinLibraryName or name == MeshKit.PropLibraryName
end

-- 조각 이름 앞머리로 어느 파일(보관함)의 조각인지 : SK_ 스킨 · PR_ 배 소품 · 나머지 기본
local function libraryNameOf(name)
	local prefix = name:sub(1, 3)
	if prefix == "SK_" then
		return MeshKit.SkinLibraryName
	elseif prefix == "PR_" then
		return MeshKit.PropLibraryName
	end
	return MeshKit.LibraryName
end

-- 서버 : Studio 에서 가져온 모델(Workspace)을 ReplicatedStorage 로 옮긴다. 테이블 · 배를 세우기 전에 한 번 부른다.
local function adoptOne(libraryName)
	local existing = ReplicatedStorage:FindFirstChild(libraryName)
	if isLibrary(existing, libraryName) then
		libraries[libraryName] = existing
		fixes[libraryName] = detectFix(libraryName, existing)
		return existing
	end
	local places = { workspace, game:GetService("ServerStorage"), ReplicatedStorage }
	local packageRoot = ReplicatedStorage:FindFirstChild("CursedBarrel")
	if packageRoot then
		table.insert(places, packageRoot)
	end
	for _, place in ipairs(places) do
		for _, child in ipairs(place:GetChildren()) do
			if child ~= existing and isLibrary(child, libraryName) then
				child.Name = libraryName
				-- 보관함의 조각은 보이지도 부딪히지도 않는다 (Workspace 에 있을 때 잠깐이라도)
				for _, piece in ipairs(child:GetDescendants()) do
					if piece:IsA("BasePart") then
						piece.Anchored = true
						piece.CanCollide = false
						piece.CanTouch = false
						piece.CanQuery = false
					end
				end
				child.Parent = ReplicatedStorage
				libraries[libraryName] = child
				fixes[libraryName] = detectFix(libraryName, child)
				table.clear(templates)
				print(("[CursedBarrel] Blender 3D 모델을 찾았습니다: %s (%s)"):format(libraryName, place.Name))
				return child
			end
		end
	end
	return nil
end

function MeshKit.adopt()
	if not RunService:IsServer() then
		return MeshKit.library()
	end
	local found = nil
	for _, libraryName in ipairs(MeshKit.LibraryNames) do
		found = adoptOne(libraryName) or found
	end
	return found
end

local function libraryOf(libraryName)
	local cached = libraries[libraryName]
	if cached and cached.Parent then
		return cached
	end
	local found = ReplicatedStorage:FindFirstChild(libraryName)
	if isLibrary(found, libraryName) then
		libraries[libraryName] = found
		fixes[libraryName] = detectFix(libraryName, found)
		table.clear(templates)
		return found
	end
	return nil
end

-- 이 조각을 놓을 때 곱할 돌림 (가져오기가 180° 돌려 넣었으면 되돌린다)
function MeshKit.fixOf(name)
	local libraryName = libraryNameOf(name)
	if not libraryOf(libraryName) then
		return IDENTITY
	end
	return fixes[libraryName] or IDENTITY
end

function MeshKit.library()
	return libraryOf(MeshKit.LibraryName)
end

function MeshKit.skinLibrary()
	return libraryOf(MeshKit.SkinLibraryName)
end

function MeshKit.propLibrary()
	return libraryOf(MeshKit.PropLibraryName)
end

function MeshKit.template(name)
	local cached = templates[name]
	if cached and cached.Parent then
		return cached
	end
	local root = libraryOf(libraryNameOf(name))
	if not root then
		return nil
	end
	local piece = root:FindFirstChild(name, true)
	if piece and piece:IsA("MeshPart") then
		templates[name] = piece
		return piece
	end
	return nil
end

-- 이 묶음(Catalog.Assets)의 조각이 전부 있는가
function MeshKit.has(asset)
	local names = Catalog.Assets[asset]
	if not names then
		return false
	end
	for _, name in ipairs(names) do
		if not (Catalog.Pieces[name] and MeshKit.template(name)) then
			return false
		end
	end
	return true
end

local function scaleOf(value)
	if typeof(value) == "Vector3" then
		return value
	end
	local n = tonumber(value) or 1
	return Vector3.new(n, n, n)
end

--[[
	조각 하나를 놓는다.
	  origin : 묶음의 기준 CFrame (world 조각은 무시하고 월드 좌표 그대로)
	  opts   : parent · name · scale(숫자 또는 Vector3) · color · material · reflectance · transparency · shadow
]]
function MeshKit.place(name, origin, opts)
	opts = opts or {}
	local template = MeshKit.template(name)
	local info = Catalog.Pieces[name]
	if not template or not info then
		return nil
	end
	local part = template:Clone()
	for _, child in ipairs(part:GetChildren()) do
		-- 가져올 때 붙은 텍스처 · 표면 · 이음새는 쓰지 않는다 (색은 부르는 쪽이 칠한다)
		if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("JointInstance")
			or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	pcall(function()
		part.TextureID = ""
	end)
	local scale = scaleOf(opts.scale)
	part.Name = opts.name or name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = opts.shadow == true
	part.Size = info.size * scale
	local fix = MeshKit.fixOf(name)
	if info.world then
		part.CFrame = CFrame.new(info.center) * fix
	else
		part.CFrame = (origin or CFrame.new()) * CFrame.new(info.center * scale) * fix
	end
	if opts.color then
		part.Color = opts.color
	end
	if opts.material then
		part.Material = opts.material
	end
	part.Reflectance = opts.reflectance or 0
	part.Transparency = opts.transparency or 0
	part:SetAttribute("MeshKit", name)
	part.Parent = opts.parent
	return part
end

-- 묶음 하나를 통째로 놓는다. styles[조각 이름] = opts (없으면 base 를 쓴다). 조각 목록을 돌려준다.
function MeshKit.build(asset, origin, base, styles)
	if not MeshKit.has(asset) then
		return nil
	end
	local made = {}
	for _, name in ipairs(Catalog.Assets[asset]) do
		local opts = table.clone(base or {})
		for key, value in pairs((styles and styles[name]) or {}) do
			opts[key] = value
		end
		local part = MeshKit.place(name, origin, opts)
		if part then
			table.insert(made, part)
		end
	end
	return made
end

-- 통 스킨에 맞는 몸통 모양 : 드럼통 스킨(drum · ribbed)은 철제 드럼, 나머지는 나무통
function MeshKit.barrelAsset(skin)
	if skin and (skin.drum or skin.ribbed) then
		return "Drum"
	end
	return "Cask"
end

--[[
	통 몸통 메시 (게임 테이블 · 전시대 · 상점 미리보기가 같이 쓴다)
	  bodyCFrame : 원통 파트의 CFrame (원통의 X 축이 세로)
	  length · diameter : 원통 파트의 길이 · 지름. 메시는 높이 4 · 지름 3.5 기준으로 만들어져 있어서 비율대로 늘린다.
	돌려주는 값 : 만든 조각 목록 (메시가 없으면 nil)
]]
function MeshKit.barrel(skin, parent, bodyCFrame, length, diameter, name)
	local asset = MeshKit.barrelAsset(skin)
	if not MeshKit.has(asset) or not skin then
		return nil
	end
	-- 원통 파트의 +X 를 위로 세운 좌표계
	local up = bodyCFrame.RightVector
	if up.Y < 0 then
		up = -up
	end
	local look = bodyCFrame.LookVector - up * bodyCFrame.LookVector:Dot(up)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	local origin = CFrame.lookAt(bodyCFrame.Position, bodyCFrame.Position + look.Unit, up)
	local scale = Vector3.new(diameter / 3.5, length / 4, diameter / 3.5)
	local body = { color = skin.body, material = skin.bodyMaterial, reflectance = skin.reflectance, parent = parent, scale = scale }
	local hoop = { color = skin.hoop, material = skin.hoopMaterial or Enum.Material.Metal, reflectance = skin.reflectance }
	local styles = {
		CB_Cask_Staves = { name = name or "MeshBody" },
		CB_Cask_Hoops = hoop,
		CB_Drum_Shell = { name = name or "MeshBody" },
		CB_Drum_Rings = hoop,
	}
	local made = MeshKit.build(asset, origin, body, styles)
	if made then
		-- Phase 17 : 스킨별 장식 (보물 · 김치통 · 화산 · 유빙 · 심연 · 용의 봉인)
		for _, part in ipairs(MeshKit.barrelDecor(skin, parent, origin, scale)) do
			table.insert(made, part)
		end
		-- 용 · 룬 고리 연출(SkinMotion)이 도는 축과 크기
		if parent then
			parent:SetAttribute("MeshFrame", origin)
			parent:SetAttribute("MeshScale", math.min(scale.X, scale.Y))
		end
	end
	return made
end


--------------------------------------------------
-- Phase 17 : Blender 스킨 조각
--------------------------------------------------

local RANK = { common = 1, rare = 2, epic = 3, legend = 4, mythic = 5 }
MeshKit.Rank = RANK
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- 조각 이름의 마지막 토막 (SK_Knife_dagger_Blade → Blade)
local function slotOf(name)
	local info = Catalog.Pieces[name]
	return info and info.slot or name:match("_([^_]+)$")
end
MeshKit.slotOf = slotOf

-- 칼 : KnifeModel 과 같은 약속 (base = 코등이 자리, 칼끝 = base 의 +Y). 스킨 색을 조각마다 칠한다.
function MeshKit.knifeStyles(skin)
	local blade = skin.blade or Color3.fromRGB(206, 210, 214)
	local bladeMaterial = skin.bladeMaterial or Enum.Material.Metal
	local guard = skin.guard or Color3.fromRGB(126, 104, 62)
	local handle = skin.handle or Color3.fromRGB(64, 42, 28)
	local neon = bladeMaterial == Enum.Material.Neon
	return {
		Blade = { color = blade, material = bladeMaterial, reflectance = skin.glow and 0.25 or 0.12 },
		Edge = { color = blade:Lerp(WHITE, 0.45), material = neon and Enum.Material.Neon or Enum.Material.Metal, reflectance = 0.2 },
		Guard = { color = guard, material = Enum.Material.Metal, reflectance = 0.15 },
		Pommel = { color = guard, material = Enum.Material.Metal, reflectance = 0.15 },
		Handle = { color = handle, material = skin.handleMaterial or Enum.Material.Wood },
		Wrap = { color = handle:Lerp(BLACK, 0.45), material = Enum.Material.Fabric },
		Gem = { color = skin.trail or blade, material = Enum.Material.Neon },
	}
end

function MeshKit.hasKnife(skin)
	return skin ~= nil and MeshKit.has("Knife_" .. tostring(skin.shape or "dagger"))
end

-- 칼 조각을 놓는다. 조각 이름은 칸 이름(Blade · Edge · Guard …)이 된다. 돌려주는 값 : 조각 목록, Blade 조각
function MeshKit.knife(skin, parent, base, scale)
	if not MeshKit.hasKnife(skin) then
		return nil
	end
	local rank = RANK[skin.rarity or "common"] or 1
	local styles = MeshKit.knifeStyles(skin)
	local made, blade = {}, nil
	for _, name in ipairs(Catalog.Assets["Knife_" .. tostring(skin.shape or "dagger")]) do
		local slot = slotOf(name)
		if slot ~= "Gem" or rank >= 2 then
			local opts = table.clone(styles[slot] or {})
			opts.parent = parent
			opts.name = slot
			opts.scale = scale or 1
			local part = MeshKit.place(name, base, opts)
			if part then
				table.insert(made, part)
				if slot == "Blade" then
					blade = part
				end
			end
		end
	end
	return made, blade
end

-- 통 장식 (Blender) : 칼이 꽂히는 가운데 띠는 비워 두고 위 테두리 · 발치 · 뚜껑 둘레만 꾸민다
MeshKit.BarrelDecor = {
	treasure = "treasure", kimchi = "kimchi", volcano = "volcano", frost = "frost", abyss = "abyss",
	tide_dragon = "dragon", crimson_dragon = "dragon", moon_dragon = "dragon",
}

function MeshKit.barrelDecorStyles(skin)
	local hoop = skin.hoop or Color3.fromRGB(58, 48, 42)
	local body = skin.body or Color3.fromRGB(122, 78, 44)
	local glow = skin.glow or hoop
	local emit = (skin.fx and skin.fx.emit) or glow
	return {
		Gold = { color = hoop, material = Enum.Material.Metal, reflectance = 0.2 },
		Coin = { color = Color3.fromRGB(255, 214, 90), material = Enum.Material.Metal, reflectance = 0.25 },
		Gem = { color = emit, material = Enum.Material.Neon },
		Latch = { color = hoop, material = Enum.Material.Plastic },
		Rock = { color = body, material = Enum.Material.Basalt },
		Glow = { color = skin.hoopMaterial == Enum.Material.Neon and hoop or emit, material = Enum.Material.Neon },
		Crystal = { color = hoop, material = Enum.Material.Glass, transparency = 0.15 },
		Ice = { color = skin.lid or hoop, material = Enum.Material.Ice },
		Tentacle = { color = body:Lerp(Color3.fromRGB(96, 60, 150), 0.55), material = Enum.Material.SmoothPlastic },
		Claw = { color = hoop, material = Enum.Material.Metal, reflectance = 0.2 },
		Chain = { color = Color3.fromRGB(70, 74, 80), material = Enum.Material.Metal },
		Seal = { color = Color3.fromRGB(245, 230, 190), material = Enum.Material.SmoothPlastic },
	}
end

function MeshKit.barrelDecor(skin, parent, origin, scale)
	local theme = skin and MeshKit.BarrelDecor[skin.id]
	if not theme or not MeshKit.has("BarrelDecor_" .. theme) then
		return {}
	end
	local styles = MeshKit.barrelDecorStyles(skin)
	local made = {}
	for _, name in ipairs(Catalog.Assets["BarrelDecor_" .. theme]) do
		local slot = slotOf(name)
		local opts = table.clone(styles[slot] or {})
		opts.parent = parent
		opts.name = "Decor" .. slot
		opts.scale = scale
		local part = MeshKit.place(name, origin, opts)
		if part then
			table.insert(made, part)
		end
	end
	return made
end

--------------------------------------------------
-- Phase 24.12 : 배 소품 (CursedBarrelProps)
--   조각 이름의 끝 토막(Wood · Iron · Brass …)이 색 · 재질을 정한다. 부르는 쪽이 styles 로 바꿀 수 있다.
--------------------------------------------------
local WOOD = Color3.fromRGB(120, 78, 44)
local DARK_WOOD = Color3.fromRGB(74, 48, 30)
local BRASS = { color = Color3.fromRGB(191, 142, 67), material = Enum.Material.Metal, reflectance = 0.15 }
MeshKit.PropStyles = {
	Wood = { color = WOOD, material = Enum.Material.Wood },
	Balusters = { color = WOOD, material = Enum.Material.Wood },
	Wheel = { color = WOOD, material = Enum.Material.Wood },
	Base = { color = Color3.fromRGB(110, 70, 40), material = Enum.Material.Wood },
	Top = { color = Color3.fromRGB(130, 86, 50), material = Enum.Material.Wood },
	Planks = { color = Color3.fromRGB(126, 84, 48), material = Enum.Material.Wood },
	Yard = { color = Color3.fromRGB(110, 72, 40), material = Enum.Material.Wood },
	DarkWood = { color = DARK_WOOD, material = Enum.Material.Wood },
	Rim = { color = DARK_WOOD, material = Enum.Material.Wood },
	Stand = { color = DARK_WOOD, material = Enum.Material.Wood },
	Iron = { color = Color3.fromRGB(46, 48, 54), material = Enum.Material.Metal },
	Brass = BRASS,
	Band = BRASS,
	Fittings = BRASS,
	Glass = { color = Color3.fromRGB(255, 193, 93), material = Enum.Material.Neon, transparency = 0.1 },
	Rope = { color = Color3.fromRGB(150, 120, 80), material = Enum.Material.Fabric },
	Cloth = { color = Color3.fromRGB(228, 214, 182), material = Enum.Material.Fabric },
	Seam = { color = Color3.fromRGB(190, 172, 138), material = Enum.Material.Fabric },
	Cushion = { color = Color3.fromRGB(128, 30, 34), material = Enum.Material.Fabric },
	Dark = { color = Color3.fromRGB(18, 14, 12), material = Enum.Material.SmoothPlastic },
	Stone = { color = Color3.fromRGB(58, 46, 40), material = Enum.Material.Slate },
	-- Phase 24.13 : 배 옆벽 · 돛대 · 게시판 · 왕좌 스킨 · 이펙트
	Cap = { color = DARK_WOOD, material = Enum.Material.Wood },
	Wale = { color = Color3.fromRGB(56, 38, 26), material = Enum.Material.Wood },
	Rail = { color = Color3.fromRGB(100, 64, 36), material = Enum.Material.Wood },
	Frame = { color = Color3.fromRGB(42, 28, 24), material = Enum.Material.Wood },
	Panel = { color = Color3.fromRGB(140, 30, 40), material = Enum.Material.SmoothPlastic },
	Gem = { color = Color3.fromRGB(80, 235, 212), material = Enum.Material.Neon },
	Horns = { color = Color3.fromRGB(230, 214, 170), material = Enum.Material.SmoothPlastic },
	Gold = { color = Color3.fromRGB(255, 200, 70), material = Enum.Material.Metal, reflectance = 0.25 },
	Star = { color = Color3.fromRGB(255, 230, 120), material = Enum.Material.Neon },
	Ring = { color = Color3.fromRGB(80, 235, 212), material = Enum.Material.Neon },
	Crystal = { color = Color3.fromRGB(150, 110, 255), material = Enum.Material.Neon },
	Feather = { color = Color3.fromRGB(255, 120, 60), material = Enum.Material.Neon },
	Bone = { color = Color3.fromRGB(235, 228, 205), material = Enum.Material.SmoothPlastic },
}

--[[
	소품 하나를 통째로 놓는다. 없으면 nil (부르는 쪽은 예전 파트 모양을 그대로 쓴다).
	  origin : 소품의 기준 CFrame (자리는 props/assets.py 의 설명을 따른다)
	  opts   : scale (숫자 · Vector3) · slotScale[slot] · styles[slot] · shadow (기본 true) · prefix (조각 이름 앞머리)
]]
function MeshKit.prop(asset, origin, parent, opts)
	if not MeshKit.has(asset) then
		return nil
	end
	opts = opts or {}
	local made = {}
	for _, name in ipairs(Catalog.Assets[asset]) do
		local slot = slotOf(name)
		local o = table.clone(MeshKit.PropStyles[slot] or {})
		for key, value in pairs((opts.styles and opts.styles[slot]) or {}) do
			o[key] = value
		end
		o.parent = parent
		o.name = (opts.prefix or asset) .. slot
		o.scale = (opts.slotScale and opts.slotScale[slot]) or opts.scale or 1
		o.shadow = opts.shadow ~= false
		local part = MeshKit.place(name, origin, o)
		if part then
			table.insert(made, part)
		end
	end
	return made
end

-- Phase 24.14 : 파트로 세운 기둥 · 들보를 Blender 기둥(Post) · 들보(ArchBeam)로 바꾼다. 원래 파트는 부딪힘만 맡는다.
--   GatePost · ArchPost · Post 는 기둥, PostCap · PostKnob · ArchTrim 은 기둥 · 들보 메시에 들어 있어 숨긴다.
function MeshKit.dressPosts(container)
	if not container or not MeshKit.has("Post") then
		return
	end
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("BasePart") and c.Transparency < 1 then
			local n, s = c.Name, c.Size
			if n == "GatePost" or n == "ArchPost" or n == "Post" then
				MeshKit.prop("Post", c.CFrame * CFrame.new(0, -s.Y / 2, 0), container, {
					scale = Vector3.new(s.X / 0.9, s.Y / 10.2, s.Z / 0.9),
					styles = { Wood = { color = c.Color, material = Enum.Material.Wood } },
				})
				c.Transparency = 1
			elseif n == "PostCap" or n == "PostKnob" or n == "ArchTrim" then
				c.Transparency = 1
			elseif n == "ArchBeam" and MeshKit.has("ArchBeam") then
				MeshKit.prop("ArchBeam", c.CFrame, container, {
					scale = Vector3.new(s.X / 10.3, s.Y / 0.9, s.Z / 1.1),
					styles = { Wood = { color = c.Color, material = Enum.Material.Wood } },
				})
				c.Transparency = 1
			end
		end
	end
end

return MeshKit
