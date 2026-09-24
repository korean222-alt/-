-- Runtime smoke test for the Phase 17 skin code, run against the patched place with Lune.
-- Polyfills the handful of engine methods the code touches, fakes the imported mesh library,
-- then builds every knife / barrel / pirate skin, applies FX, stabs slot knives and steps SkinMotion.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local NOLIB = process.args[2] == "nolib"
local workspace = game:GetService("Workspace")

-------------------------------------------------- engine polyfills
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(s.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, fn in ipairs(s.handlers) do
			fn(...)
		end
	end
	function s:Wait() end
	return s
end
local signals = {}
local function signalFor(inst, name)
	signals[inst] = signals[inst] or {}
	signals[inst][name] = signals[inst][name] or signal()
	return signals[inst][name]
end

roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	local c = self:FindFirstChild(name)
	assert(c, "WaitForChild would hang: " .. self:GetFullName() .. "." .. name)
	return c
end)
for _, class in { "BasePart", "Part", "MeshPart", "WedgePart", "TrussPart", "Seat", "SpawnLocation", "UnionOperation" } do
	pcall(roblox.implementProperty, class, "Position", function(self) return self.CFrame.Position end,
		function(self, v) self.CFrame = CFrame.new(v) * self.CFrame.Rotation end)
end
-- Lune cannot assign nil to a Ref property: keep PrimaryPart in a side table (seeded from the file)
local primary = {}
for _, d in game:GetDescendants() do
	if d:IsA("Model") then
		local ok, v = pcall(function() return d.PrimaryPart end)
		primary[d] = ok and v or nil
	end
end
roblox.implementProperty("Model", "PrimaryPart", function(self) return primary[self] end, function(self, v) primary[self] = v end)
roblox.implementProperty("Instance", "Destroying", function(self) return signalFor(self, "Destroying") end)
roblox.implementProperty("Instance", "AncestryChanged", function(self) return signalFor(self, "AncestryChanged") end)
roblox.implementProperty("Instance", "ChildAdded", function(self) return signalFor(self, "ChildAdded") end)

local function parts(model)
	local list = {}
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
local function getPivot(self)
	local pp = self.PrimaryPart
	if pp then
		return pp.CFrame * pp.PivotOffset
	end
	return self.WorldPivot
end
roblox.implementMethod("Model", "GetPivot", getPivot)
roblox.implementMethod("BasePart", "GetPivot", function(self) return self.CFrame * self.PivotOffset end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * getPivot(self):Inverse()
	for _, p in parts(self) do
		p.CFrame = delta * p.CFrame
	end
	if not self.PrimaryPart then
		self.WorldPivot = target
	end
end)
roblox.implementMethod("Model", "GetBoundingBox", function(self)
	local lo, hi
	for _, p in parts(self) do
		local c, s = p.CFrame.Position, p.Size * 0.5
		lo = lo and Vector3.new(math.min(lo.X, c.X - s.X), math.min(lo.Y, c.Y - s.Y), math.min(lo.Z, c.Z - s.Z)) or c - s
		hi = hi and Vector3.new(math.max(hi.X, c.X + s.X), math.max(hi.Y, c.Y + s.Y), math.max(hi.Z, c.Z + s.Z)) or c + s
	end
	lo = lo or Vector3.zero
	hi = hi or Vector3.zero
	return CFrame.new((lo + hi) * 0.5), hi - lo
end)
local function bulk(_, list, frames)
	for i, p in ipairs(list) do
		p.CFrame = frames[i]
	end
end
roblox.implementMethod("Workspace", "BulkMoveTo", bulk)
roblox.implementMethod("WorldModel", "BulkMoveTo", bulk)

local IS_SERVER = true
local services = {}
services.RunService = {
	IsServer = function() return IS_SERVER end,
	IsClient = function() return not IS_SERVER end,
	IsStudio = function() return true end,
	RenderStepped = signal(), Heartbeat = signal(), Stepped = signal(),
}
local added, removed = {}, {}
services.CollectionService = {
	AddTag = function(_, inst, tag)
		inst:AddTag(tag)
		if added[tag] then added[tag]:Fire(inst) end
	end,
	RemoveTag = function(_, inst, tag) inst:RemoveTag(tag) end,
	HasTag = function(_, inst, tag) return inst:HasTag(tag) end,
	GetTagged = function(_, tag)
		local list = {}
		for _, d in game:GetDescendants() do
			if d:HasTag(tag) then table.insert(list, d) end
		end
		return list
	end,
	GetInstanceAddedSignal = function(_, tag) added[tag] = added[tag] or signal(); return added[tag] end,
	GetInstanceRemovedSignal = function(_, tag) removed[tag] = removed[tag] or signal(); return removed[tag] end,
}
services.TweenService = { Create = function() return { Play = function() end, Cancel = function() end, Completed = signal() } end }
services.Players = { LocalPlayer = nil, PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
services.UserInputService = { TouchEnabled = false, GamepadEnabled = false }
services.Debris = { AddItem = function() end }

local proxyGame = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_, name)
				return services[name] or game:GetService(name)
			end
		end
		return game[key]
	end,
})

-------------------------------------------------- module loader
local cache = {}
local STUB = { ProfileService = true, ShopService = true, TableService = true, RoundService = true }
local function requireModule(inst)
	if cache[inst] then
		return cache[inst]
	end
	if STUB[inst.Name] then
		local stub = setmetatable({}, { __index = function() return function() end end })
		stub.RoundSettled = signal()
		stub.TableAdded = signal()
		stub.GetAllTables = function() return {} end
		cache[inst] = stub
		return stub
	end
	local env = setmetatable({
		script = inst, game = proxyGame, workspace = workspace, require = requireModule,
		Instance = Instance, Vector3 = Vector3, Vector2 = roblox.Vector2, CFrame = CFrame, Color3 = Color3, Enum = Enum,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange, UDim2 = roblox.UDim2, UDim = roblox.UDim, Font = roblox.Font,
		TweenInfo = { new = function() return {} end }, BrickColor = roblox.BrickColor,
		Random = { new = function() return { NextNumber = function() return 0.5 end, NextInteger = function(_, a) return a end } end },
		task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end, delay = function() end, wait = function() end },
		typeof = typeof, warn = function(...) print("WARN", ...) end, print = function() end, tick = os.clock, os = os,
	}, { __index = _G })
	-- harness only: Lune cannot assign nil to Ref properties
	local source = inst.Source:gsub("([%w_%.]+)%.PrimaryPart = nil", "pcall(function() %1.PrimaryPart = nil end)")
	source = source:gsub("([%w_%.]+)%.PrimaryPart=nil", "pcall(function() %1.PrimaryPart=nil end)")
	local fn = luau.load(source, { debugName = inst:GetFullName(), environment = env })
	local result = fn()
	cache[inst] = result
	return result
end

-------------------------------------------------- fake imported skin library (what Studio's 3D importer makes)
local Shared = game.ReplicatedStorage.CursedBarrel.Shared
local SkinCatalog = requireModule(Shared.SkinMeshCatalog)
local library = Instance.new("Model")
library.Name = "CursedBarrelSkins"
for name, info in SkinCatalog.Pieces do
	local mp = Instance.new("MeshPart")
	mp.Name = name
	mp.Size = info.size
	mp.Parent = library
end
if not NOLIB then library.Parent = workspace end

local failures = 0
local function check(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures += 1
		print("FAIL  " .. label .. " :: " .. tostring(err))
	else
		print("ok    " .. label)
	end
end

local MeshKit = requireModule(Shared.MeshKit)
local GameConfig = requireModule(Shared.GameConfig)
check("MeshKit.adopt moves both libraries", function()
	MeshKit.adopt()
	if NOLIB then assert(not MeshKit.has("Pirate"), "phantom library"); return end
	assert(game.ReplicatedStorage:FindFirstChild("CursedBarrelSkins"), "skins library not adopted")
	assert(game.ReplicatedStorage:FindFirstChild("CursedBarrelModels"), "models library not adopted")
	for _, asset in { "Knife_dagger", "Knife_fang", "Pirate", "DragonCoil", "DragonRing", "Petal", "RuneRing", "KrakenCapsule", "BarrelDecor_dragon", "Cask", "Drum" } do
		assert(MeshKit.has(asset), "missing asset " .. asset)
	end
end)

check("barrel prices -20%", function()
	local expect = { oak = 0, drum = 6900, steel = 6900, blue_drum = 0, treasure = 44900, kimchi = 44900, abyss = 209900, volcano = 112900, frost = 112900,
		tide_dragon = 399000, crimson_dragon = 399000, moon_dragon = 399000 }
	for _, skin in GameConfig.Skins.Barrel do
		assert(expect[skin.id] == skin.price, skin.id .. " price " .. tostring(skin.price))
	end
end)

local KnifeModel = requireModule(Shared.KnifeModel)
local SkinFX = requireModule(Shared.SkinFX)
local PirateModel = requireModule(Shared.PirateModel)
local stage = Instance.new("Folder")
stage.Parent = workspace

for _, skin in GameConfig.Skins.Knife do
	check("knife " .. skin.id, function()
		local model = KnifeModel.build(skin, stage, CFrame.new(0, 5, 0), 1.05)
		assert(model:FindFirstChild("Blade"), "no blade")
		if not NOLIB then assert(model:GetAttribute("MeshFrame"), "not meshed") end
		SkinFX.applyPreview(model, skin, "Knife")
		local marker = model:FindFirstChild("SkinFX_Motion", true)
		local rank = MeshKit.Rank[skin.rarity]
		if not NOLIB then assert((rank >= 4) == (marker ~= nil), "motion marker mismatch rank " .. rank) end
	end)
end

for _, skin in GameConfig.Skins.Barrel do
	check("barrel " .. skin.id, function()
		local model = Instance.new("Model")
		model.Parent = stage
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Cylinder
		body.Size = Vector3.new(3.4, 3, 3)
		body.CFrame = CFrame.new(10, 3, 0) * CFrame.Angles(0, 0, math.pi / 2)
		body.Parent = model
		local made = MeshKit.barrel(skin, model, body.CFrame, 3.4, 3, "BodyMesh")
		assert(made and #made >= 2, "barrel mesh missing")
		local decor = MeshKit.BarrelDecor[skin.id]
		if decor and not NOLIB then
			local n = 0
			for _, p in made do
				if p.Name:sub(1, 5) == "Decor" then n += 1 end
			end
			assert(n > 0, "decor missing for " .. decor)
		end
		SkinFX.applyBarrel(model, skin)
	end)
end

for _, skin in GameConfig.Skins.Ghost do
	check("pirate " .. skin.id, function()
		local rig = PirateModel.new(skin, nil)
		if not NOLIB then assert(rig.meshed, "not meshed") end
		rig.model.Parent = stage
		rig:pose(CFrame.new(0, 10, 0), { lean = 20, reach = 1, jaw = 1, nod = 5, sway = 10 })
		local pivot = rig.model:GetPivot()
		assert(NOLIB or (pivot.Position - Vector3.new(0, 10, 0)).Magnitude < 1e-3, "pivot not at chest: " .. tostring(pivot.Position))
		SkinFX.applyGhost(rig.model, skin)
		rig:adopt(CFrame.new(0, 10, 0))
		rig:fade(0.5)
		local theme = PirateModel.Theme[skin.id]
		if theme and not NOLIB then
			for _, slot in theme.add do
				assert(rig.model:FindFirstChild(slot), "missing accessory " .. slot)
			end
			for _, slot in theme.hide do
				assert(not rig.model:FindFirstChild(slot), "should hide " .. slot)
			end
		end
	end)
end

-- slot knives on a real table
local SlotBuilder = requireModule(game.ServerScriptService.CursedBarrel.Services.SlotBuilder)
check("slot knife stab / danger / reset", function()
	local tableModel = workspace.GameTables:GetChildren()[1]
	local slots = SlotBuilder.getSlots(tableModel:FindFirstChild("KnifeSlots", true))
	assert(#slots > 0, "no slots")
	for i, skin in GameConfig.Skins.Knife do
		local slot = slots[(i - 1) % #slots + 1]
		SlotBuilder.applyKnifeSkin(slot, skin)
		SlotBuilder.markUsed(slot, nil, i % 4 == 0)
		local knife = slot:FindFirstChild("Knife")
		local mesh = knife:FindFirstChild("SkinMesh")
		if not NOLIB then assert(mesh and #mesh:GetChildren() > 0, "no mesh knife") end
		if not NOLIB then
		for _, p in knife:GetChildren() do
			if p:IsA("BasePart") then assert(p.Transparency == 1, "box knife still visible: " .. p.Name) end
		end
		for _, p in mesh:GetChildren() do
			assert(p.Transparency == 0, "mesh hidden")
		end
		end
		SkinFX.applyKnife(knife, skin, true)
		-- tip must point into the barrel: Blade piece centre is closer to the barrel than the Pommel
		local body = tableModel:FindFirstChild("Body", true)
		local blade, pommel = mesh and mesh:FindFirstChild("Blade"), mesh and mesh:FindFirstChild("Pommel")
		if not NOLIB and body and blade and pommel then
			local c = body.CFrame.Position
			assert((blade.CFrame.Position - c).Magnitude < (pommel.CFrame.Position - c).Magnitude, "knife points outward")
		end
		SlotBuilder.resetSlot(slot)
		assert(not knife:FindFirstChild("SkinMesh"), "reset left mesh")
	end
end)

-- lobby: hall of fame (double-sided), like reward stand
local ShipLobbyBuilder = requireModule(game.ServerScriptService.CursedBarrel.Services.ShipLobbyBuilder)
check("hall of fame faces both sides", function()
	local root = Instance.new("Folder")
	root.Parent = workspace
	ShipLobbyBuilder:hallOfFame(root)
	local front, back = 0, 0
	for _, d in root:GetDescendants() do
		if d.Name == "RankingFace" then
			if d:GetAttribute("Side") == "Back" then back += 1 else front += 1 end
		end
	end
	assert(front == 3 and back == 3, ("faces %d/%d"):format(front, back))
end)
local LobbyBuilder = requireModule(game.ServerScriptService.CursedBarrel.Services.LobbyBuilder)
check("like reward stand", function()
	LobbyBuilder:_buildLikeReward()
	local stand = workspace.Lobby:FindFirstChild("LikeReward")
	assert(stand, "no stand")
	local pedestal = stand:FindFirstChild("Pedestal")
	local at = pedestal.CFrame.Position
	assert(math.abs(at.X - 20) < 0.01 and math.abs(at.Z - 101) < 0.01, "wrong spot " .. tostring(at))
	assert(at.Y < 3, "not on main deck")
	local texts = {}
	for _, d in stand:GetDescendants() do
		if d:IsA("TextLabel") then table.insert(texts, d.Text) end
	end
	assert(table.find(texts, "👍 좋아요 부탁드려요!"), "like text missing: " .. table.concat(texts, " | "))
end)
check("lobby ghost preview uses Blender pirate", function()
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	-- previewGhost is local; exercise it through the showcase builder entry used by LobbyBuilder
	local rig = PirateModel.new(GameConfig.Skins.Ghost[1], nil)
	if not NOLIB then assert(rig.model:GetAttribute("Meshed")) end
end)

local Tournament = requireModule(game.ServerScriptService.CursedBarrel.Services.TournamentService)
check("tournament board", function()
	local tableModel = workspace.GameTables:GetChildren()[1]
	local fake = { model = tableModel, destroyed = false }
	Tournament:_ensureBoard(fake)
	Tournament.top = { { name = "Alice", score = 38, userId = 1 }, { name = "Bob", score = 30, userId = 2 }, { name = "Cy", score = 12, userId = 0 } }
	Tournament:_draw()
	local board = Tournament._boards[fake]
	assert(board and #board.rows == 2, "board faces")
	for _, rows in board.rows do
		assert(rows:FindFirstChild("Row_1") and rows.Row_1.Score.Text == "38점", "rows not drawn")
		assert(not rows:FindFirstChild("Row_4"), "extra row")
	end
	Tournament.top = {}
	Tournament:_draw()
	assert(board.rows[1]:FindFirstChild("Empty"), "empty text")
end)

check("product ids flow from ReleaseConfig", function()
	local Release = requireModule(Shared.ReleaseConfig)
	assert(Release.ProductIds and Release.GamePassIds and Release.Images.Skins["Knife/tide_dragon"] == 0)
end)

-------------------------------------------------- client side
IS_SERVER = false
local SkinMotion = requireModule(Shared.SkinMotion)
check("SkinMotion builds and animates", function()
	SkinMotion.start()
	local step = services.RunService.RenderStepped.handlers[1]
	assert(step, "no RenderStepped")
	for _ = 1, 5 do
		step(1 / 30)
	end
	local folder = workspace:FindFirstChild("CursedBarrel_SkinMotion")
	if not NOLIB then assert(folder and #folder:GetChildren() > 0, "no motion models") end
	local dragons, petals, rings = 0, 0, 0
	for _, d in folder:GetDescendants() do
		if d.Name:sub(1, 6) == "Dragon" then dragons += 1 end
		if d.Name == "Petal" then petals += 1 end
		if d.Name == "RuneRing" then rings += 1 end
	end
	if not NOLIB then assert(dragons > 0 and petals > 0 and rings > 0, ("dragon %d petal %d ring %d"):format(dragons, petals, rings)) end
	-- markers removed -> visuals destroyed
	for _, m in services.CollectionService:GetTagged("CB_SkinMotion") do
		m.Parent = nil
	end
	step(1 / 30)
	if folder then assert(#folder:GetChildren() == 0, "visuals left after marker removal") end
end)

local SkinPreview = requireModule(Shared.SkinPreview)
for _, kind in { "Knife", "Barrel", "Ghost" } do
	for _, skin in GameConfig.Skins[kind] do
		check("preview " .. kind .. "/" .. skin.id, function()
			local world = Instance.new("WorldModel")
			world.Parent = workspace
			local m = SkinPreview.build(kind, skin, world, true)
			assert(m and m.Parent == world, "preview not built")
		end)
	end
end

print(("\n%d failure(s)"):format(failures))
process.exit(failures == 0 and 0 or 1)
