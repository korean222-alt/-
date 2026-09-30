-- 로비 (99 Nights 처럼 모여서 출발):
--  · 원정 수레(방)에 올라타면 대원이 된다. 첫 대원이 방장 → 정원(1~6)을 정하거나 "지금 출발".
--    정원이 차면 FullWait 초, 아니면 첫 대원이 탄 뒤 RoomWait 초가 지나면 모인 인원으로 출발.
--  · "혼자 바로 출발": 기다림 없이 곧장 (들어와서 1분 안에 놀기)
--  · 부화장(알 넣기·깨우기), 내 펫(출전 팀·이름 짓기·즐겨찾기), 보급 상점(코인)
--  · 로비에 있는 동안 출전 펫 3마리가 따라다닌다 (소유욕: 빛나는 펫·별 5개를 자랑)
-- 출발: 실제 서버에서는 예약 서버로 텔레포트(같은 Place), Studio 에서는 같은 서버 안의 원정 맵으로 옮긴다.
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LC = require(RS.Shared.Config.LobbyConfig)
local EC = require(RS.Shared.Config.EggConfig)
local P = require(RS.Shared.Config.PetConfig)
local Shop = require(RS.Shared.Config.ShopConfig)
local R = require(RS.Shared.Modules.PetRules)
local U = require(RS.Shared.Modules.Utility)
local LobbyLook = require(RS.Shared.Visuals.Lobby)
local S = {}

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function S:Init(ctx, origin)
	self.ctx = ctx
	self.Players, self.Rooms, self.Last, self.Pets, self.NextState = {}, {}, {}, {}, 0
	self.Scene = LobbyLook.build(ctx.Map.Root, origin, LC)
	for i, pad in ipairs(self.Scene.Pads) do
		self.Rooms[i] = {Id = i, Pad = pad, Sign = self.Scene.Signs[i], Members = {}, Size = LC.DefaultSize}
	end
	local eggs = U.prompt(self.Scene.Incubator, "Eggs", "알 부화장 열기", Enum.KeyCode.E, Vector3.new(0, 1, 0))
	eggs.ObjectText = "부화장"
	eggs.Triggered:Connect(function(player) if self.Players[player] then ctx.LobbyEvent:FireClient(player, "Open", "Eggs") end end)
	local shop = U.prompt(self.Scene.Shop, "Shop", "보급 상점 · 도감", Enum.KeyCode.E, Vector3.new(0, -1, -1))
	shop.ObjectText = "게시판"
	shop.Triggered:Connect(function(player) if self.Players[player] then ctx.LobbyEvent:FireClient(player, "Open", "Shop") end end)
	ctx.LobbyAction.OnServerEvent:Connect(function(player, action, value) self:Action(player, action, value) end)
end

-- ===================================================================== 들어오고 나가기
function S:Add(player)
	if self.Players[player] then return end
	self.Players[player] = {}
	player:SetAttribute("Place", "Lobby")
	player.RespawnLocation = self.Scene.Spawn
	-- 원정 도구는 로비에 가져오지 않는다
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then backpack:ClearAllChildren() end
	local character = player.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then tool:Destroy() end
		end
		if character.Parent then character:PivotTo(self.Scene.Spawn.CFrame + Vector3.new(0, 4, 0)) end
	end
	self:SpawnPets(player)
end

function S:OnSpawn(player, character)
	local waited = 0
	while not character:IsDescendantOf(workspace) and waited < 10 do waited = waited + task.wait(0.1) end
	if self.Players[player] and player.Character == character then
		character:PivotTo(self.Scene.Spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

function S:Remove(player)
	self:LeaveRoom(player)
	self:DespawnPets(player)
	self.Players[player], self.Last[player] = nil, nil
end

-- ===================================================================== 따라다니는 펫
function S:DespawnPets(player)
	for _, entry in ipairs(self.Pets[player] or {}) do entry.Part:Destroy() end
	self.Pets[player] = nil
end

function S:SpawnPets(player)
	self:DespawnPets(player)
	local profile = self.ctx.Data:Get(player)
	if not profile or not self.Players[player] then return end
	local list = {}
	local root = U.aliveRoot(player)
	local from = root and root.Position or self.Scene.Spawn.Position
	for i, uid in ipairs(profile.Party) do
		local pet = profile.Pets[uid]
		if pet then
			local stats = R.stats(pet, P)
			local part = U.part(self.ctx.Map.PetsFolder, "Lobby_" .. uid, Vector3.new(2, 2, 2), Vector3.new(from.X + i * 3, self.Scene.Center.Y + 1, from.Z + 5))
			part.Transparency, part.CanCollide, part.CanTouch, part.CanQuery = 1, false, false, false
			for key, value in pairs({SpeciesId = pet.SpeciesId, OwnerId = player.UserId, OwnerName = player.DisplayName, Uid = uid, Stage = R.stage(pet),
				Stars = pet.Stars or 2, Shiny = pet.Shiny == true, Trait = pet.Trait or "", Nickname = pet.Nickname or "", Level = pet.Level,
				HP = stats.HP, MaxHP = stats.HP, Status = "영구", Mode = "Follow"}) do
				part:SetAttribute(key, value)
			end
			table.insert(list, {Part = part, Index = i})
		end
	end
	self.Pets[player] = list
end

function S:MovePets(dt)
	for player, list in pairs(self.Pets) do
		local root = U.aliveRoot(player)
		if root then
			for _, entry in ipairs(list) do
				local goal = root.Position + root.CFrame.RightVector * ((entry.Index - 2) * 4) - root.CFrame.LookVector * 5
				local pos = entry.Part.Position
				local delta = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
				if delta.Magnitude > 30 then
					entry.Part.Position = Vector3.new(goal.X, self.Scene.Center.Y + 1, goal.Z)
				elseif delta.Magnitude > 1 then
					local nextPos = pos + delta.Unit * math.min(delta.Magnitude, P.FollowSpeed * dt)
					entry.Part.CFrame = CFrame.lookAt(nextPos, nextPos + delta.Unit)
				end
			end
		end
	end
end

-- ===================================================================== 방
function S:RoomOf(player)
	for _, room in ipairs(self.Rooms) do
		if table.find(room.Members, player) then return room end
	end
	return nil
end

function S:LeaveRoom(player)
	local room = self:RoomOf(player)
	if not room or room.Launching then return end
	table.remove(room.Members, table.find(room.Members, player))
	if #room.Members == 0 then room.LaunchAt, room.Size = nil, LC.DefaultSize end
end

function S:UpdateRooms(now)
	for player, info in pairs(self.Players) do
		local root = U.aliveRoot(player)
		local room = self:RoomOf(player)
		if room and not room.Launching then
			if not root or not player.Parent or flatDistance(root.Position, room.Pad.Position) > LC.PadRadius + 2 then self:LeaveRoom(player) end
		elseif not room and root and not info.Launching and not info.SoloAt then
			for _, candidate in ipairs(self.Rooms) do
				if not candidate.Launching and #candidate.Members < candidate.Size and flatDistance(root.Position, candidate.Pad.Position) <= LC.PadRadius then
					table.insert(candidate.Members, player)
					if #candidate.Members == 1 then
						candidate.LaunchAt = now + LC.RoomWait
						self.ctx.Notify(player, "🚚 원정 수레 " .. candidate.Id .. " 방장! 인원을 정하거나 [지금 출발] · 내리면 방에서 나가요")
					else
						self.ctx.Notify(player, "🚚 원정 수레 " .. candidate.Id .. " 에 탔습니다 · 출발을 기다려요")
					end
					break
				end
			end
		end
		if info.SoloAt and now >= info.SoloAt then
			info.SoloAt = nil
			self:Launch({player}, nil)
		end
	end
	for _, room in ipairs(self.Rooms) do
		if #room.Members > 0 and not room.Launching then
			if #room.Members >= room.Size then room.LaunchAt = math.min(room.LaunchAt, now + LC.FullWait) end
			if now >= room.LaunchAt then self:Launch(table.clone(room.Members), room) end
		end
		local text = #room.Members == 0 and ("원정 수레 " .. room.Id .. "\n타면 방이 생겨요")
			or string.format("원정 수레 %d\n👥 %d/%d · %s", room.Id, #room.Members, room.Size,
				room.Launching and "출발!" or (math.ceil(math.max(0, room.LaunchAt - now)) .. "초"))
		if room.Sign.Text ~= text then room.Sign.Text = text end
	end
end

-- ===================================================================== 출발
function S:Launch(members, room)
	local list = {}
	for _, player in ipairs(members) do
		local info = self.Players[player]
		if info and player.Parent and self.ctx.Data:Ready(player) then
			info.Launching, info.SoloAt = true, nil
			table.insert(list, player)
			self.ctx.Notify(player, "🚚 출발! 숲으로 들어갑니다")
		end
	end
	if room then room.Launching = true end
	local function reset()
		if room then room.Launching, room.Members, room.LaunchAt, room.Size = false, {}, nil, LC.DefaultSize end
	end
	if #list == 0 then reset(); return end
	if self.ctx.Mode == "Both" then
		-- Studio: 같은 서버의 원정 맵으로
		task.defer(function()
			for _, player in ipairs(list) do
				if player.Parent then
					self:Remove(player)
					self.ctx.EnterExpedition(player)
				end
			end
			reset()
		end)
	else
		task.spawn(function()
			self:Teleport(list, room and room.Id or 0)
			reset()
		end)
	end
end

-- 실제 서버: 예약 서버(같은 Place)를 만들어 함께 보낸다. 저장을 먼저 풀어야 원정 서버가 바로 불러온다.
function S:Teleport(list, roomId)
	local ok, code = pcall(function() return TeleportService:ReserveServer(game.PlaceId) end)
	local sent = false
	if ok then
		for _, player in ipairs(list) do self.ctx.Data:Save(player, true) end
		local deadline = os.clock() + 8
		repeat
			local busy = false
			for _, player in ipairs(list) do if self.ctx.Data.Sessions[player] then busy = true end end
			if busy then task.wait(0.2) end
		until not busy or os.clock() > deadline
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData({Room = roomId, Size = #list})
		sent = pcall(function() TeleportService:TeleportAsync(game.PlaceId, list, options) end)
	end
	if not sent then
		-- 실패하면 로비에 그대로 남는다 (저장을 다시 잡는다)
		for _, player in ipairs(list) do
			if player.Parent then
				local info = self.Players[player]
				if info then info.Launching = false end
				if not self.ctx.Data.Sessions[player] then self.ctx.Data:Load(player) end
				self.ctx.Notify(player, "출발하지 못했습니다. 잠시 후 다시 시도해 주세요.")
			end
		end
	end
end

-- ===================================================================== 버튼
function S:Action(player, action, value)
	local info = self.Players[player]
	if not info or type(action) ~= "string" or info.Launching then return end
	if os.clock() - (self.Last[player] or -100) < 0.25 then return end
	self.Last[player] = os.clock()
	local room = self:RoomOf(player)
	local profile = self.ctx.Data:Get(player)
	if not profile or not self.ctx.Data:Ready(player) then return end
	if action == "Solo" then
		if room then self:LeaveRoom(player) end
		info.SoloAt = os.clock() + LC.SoloDelay
	elseif action == "CancelSolo" then
		info.SoloAt = nil
	elseif action == "Size" and room and room.Members[1] == player and type(value) == "number" and value % 1 == 0
		and value >= math.max(1, #room.Members) and value <= LC.MaxSize then
		room.Size = value
	elseif action == "Go" and room and room.Members[1] == player then
		room.LaunchAt = os.clock()
	elseif action == "Incubate" then
		self.ctx.Eggs:Incubate(player, value)
	elseif action == "Hatch" then
		if self.ctx.Eggs:Hatch(player, value) then self:SpawnPets(player) end
	elseif action == "Party" and type(value) == "table" then
		local ids = R.party(value, profile.Pets, P.ActiveLimit)
		if ids then
			self.ctx.Data:Mutate(player, function(data) data.Party = ids end)
			self:SpawnPets(player)
		end
	elseif action == "Favorite" and type(value) == "string" and profile.Pets[value] then
		self.ctx.Data:Mutate(player, function(data) data.Pets[value].Favorite = not data.Pets[value].Favorite end)
	elseif action == "Rename" and type(value) == "table" and type(value.Uid) == "string" and profile.Pets[value.Uid] and type(value.Name) == "string" then
		local name = self.ctx.Pets.FilterName(player, value.Name, self.ctx)
		if name and self.ctx.Data:Ready(player) and profile.Pets[value.Uid] then
			self.ctx.Data:Mutate(player, function(data) data.Pets[value.Uid].Nickname = name ~= "" and name or nil end)
			self:SpawnPets(player)
			self.ctx.Notify(player, name ~= "" and ("이름을 지었습니다: " .. name) or "이름을 지웠습니다")
		end
	elseif action == "Perk" and type(value) == "string" then
		self:BuyPerk(player, value)
	end
end

function S:BuyPerk(player, id)
	local perk = Shop.Perks[id]
	local profile = self.ctx.Data:Get(player)
	if not perk or not profile then return end
	if profile.Perks[id] then self.ctx.Notify(player, "이미 해금했습니다."); return end
	if profile.Coins < perk.Cost then self.ctx.Notify(player, "코인이 부족합니다 · 원정에서 밤을 버티면 코인을 받아요"); return end
	self.ctx.Data:Mutate(player, function(data)
		if data.Perks[id] or data.Coins < perk.Cost then return end
		data.Coins = data.Coins - perk.Cost
		data.Perks[id] = true
	end)
	self.ctx.Notify(player, perk.Icon .. " 해금! " .. perk.Name .. " (다음 원정부터 지급)")
end

-- ===================================================================== 화면에 보낼 것
function S:State(player)
	local profile = self.ctx.Data:Get(player)
	local info = self.Players[player]
	if not profile or not info then return nil end
	local now = os.clock()
	local rooms = {}
	for _, room in ipairs(self.Rooms) do
		local names = {}
		for _, member in ipairs(room.Members) do table.insert(names, member.DisplayName) end
		table.insert(rooms, {Id = room.Id, Count = #room.Members, Size = room.Size, Names = names, Launching = room.Launching == true,
			LaunchIn = room.LaunchAt and math.max(0, room.LaunchAt - now) or nil})
	end
	local mine = self:RoomOf(player)
	local eggs = {}
	for id, egg in pairs(profile.Eggs or {}) do
		table.insert(eggs, {Id = id, Kind = egg.Kind, HatchAt = egg.HatchAt, GotAt = egg.GotAt})
	end
	table.sort(eggs, function(a, b)
		if (a.HatchAt ~= nil) ~= (b.HatchAt ~= nil) then return a.HatchAt ~= nil end
		if a.Kind ~= b.Kind then return a.Kind == "Rare" end
		return a.Id < b.Id
	end)
	local pets = {}
	for uid, pet in pairs(profile.Pets) do
		table.insert(pets, {Uid = uid, SpeciesId = pet.SpeciesId, Stage = R.stage(pet), Level = pet.Level, Stars = pet.Stars or 2, Shiny = pet.Shiny == true,
			Trait = pet.Trait, Nickname = pet.Nickname, Favorite = pet.Favorite == true, Power = R.power(pet, P), InParty = table.find(profile.Party, uid) ~= nil})
	end
	table.sort(pets, function(a, b)
		if a.InParty ~= b.InParty then return a.InParty end
		if a.Power ~= b.Power then return a.Power > b.Power end
		return a.Uid < b.Uid
	end)
	return {Rooms = rooms, MyRoom = mine and mine.Id or nil, Host = mine ~= nil and mine.Members[1] == player, Solo = info.SoloAt and math.max(0, info.SoloAt - now) or nil,
		Launching = info.Launching == true, Eggs = eggs, Slots = EC.IncubatorSlots, Now = os.time(), Pets = pets, Party = profile.Party, Coins = profile.Coins,
		Perks = profile.Perks, Dex = profile.Dex, Stats = profile.Stats, Practice = self.ctx.Data.Memory, SaveStatus = self.ctx.Data.Sessions[player] and self.ctx.Data.Sessions[player].Status}
end

-- 캠프 밖으로 떨어지거나 벽을 뚫으면 스폰으로
function S:Contain(player)
	local root = U.aliveRoot(player)
	if not root then return end
	local center = self.Scene.Center
	if root.Position.Y < center.Y - 50 or flatDistance(root.Position, center) > LC.Radius + 12 then
		root.Parent:PivotTo(self.Scene.Spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

function S:Tick(dt)
	local now = os.clock()
	self:UpdateRooms(now)
	self:MovePets(dt)
	for player in pairs(self.Players) do self:Contain(player) end
	if now >= self.NextState then
		self.NextState = now + 0.5
		for player in pairs(self.Players) do
			local state = player.Parent and self:State(player)
			if state then self.ctx.LobbyEvent:FireClient(player, "State", state) end
		end
	end
end

return S
