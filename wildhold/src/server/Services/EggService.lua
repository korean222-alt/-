-- 알: 원정 보상으로 받고(Grant), 로비 부화장에 넣고(Incubate), 시간이 되면 깨운다(Hatch).
-- 부화 결과(종·재능 별·빛나는 변종·특성)는 깨우는 순간 서버가 정한다. 시간은 실제 시각(os.time) → 원정에 나가 있어도 흐른다.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local EC = require(RS.Shared.Config.EggConfig)
local P = require(RS.Shared.Config.PetConfig)
local R = require(RS.Shared.Modules.PetRules)
local Eggs = require(RS.Shared.Modules.Eggs)
local L = require(RS.Shared.Modules.Locale)
local S = {}

function S:Init(ctx)
	self.ctx, self.Rng, self.Last = ctx, Random.new(), {}
end

function S:Scale()
	return self.ctx.Clock and self.ctx.Clock:Scale() or 1
end

-- 원정 보상. 반환: 받은 알 id (가득 차서 코인으로 바뀌었으면 nil)
function S:Grant(player, kind, reason)
	local spec = EC.Kinds[kind]
	if not spec or not self.ctx.Data:Ready(player) then return nil end
	local id, overflow = nil, false
	self.ctx.Data:Mutate(player, function(data)
		data.Eggs = data.Eggs or {}
		if R.count(data.Eggs) >= EC.Limit then
			data.Coins = data.Coins + EC.OverflowCoins
			overflow = true
		else
			id = Http:GenerateGUID(false)
			data.Eggs[id] = {Id = id, Kind = kind, GotAt = os.time()}
		end
	end)
	if overflow then
		self.ctx.Notify(player, L.M("egg.overflow", {coins = EC.OverflowCoins}))
	else
		self.ctx.Notify(player, L.M("egg.got", {icon = spec.Icon, name = L.M("egg." .. kind), why = reason or ""}))
		self.ctx.PetFX:FireClient(player, "Egg", kind)
	end
	self.ctx.Data:Save(player)
	return id
end

function S:Throttle(player)
	if os.clock() - (self.Last[player] or -100) < 0.4 then return false end
	self.Last[player] = os.clock()
	return true
end

-- 부화장에 넣기: 빈 칸이 있어야 한다. 넣는 순간부터 타이머가 돈다
function S:Incubate(player, id)
	local profile = self.ctx.Data:Get(player)
	if type(id) ~= "string" or not profile or not self:Throttle(player) then return false end
	local egg = profile.Eggs and profile.Eggs[id]
	if not egg or egg.HatchAt then return false end
	if Eggs.incubating(profile.Eggs) >= EC.IncubatorSlots then
		self.ctx.Notify(player, L.M("egg.incubatorFull"))
		return false
	end
	local seconds = math.max(1, math.floor(EC.Kinds[egg.Kind].HatchSeconds / self:Scale()))
	self.ctx.Data:Mutate(player, function() egg.HatchAt = os.time() + seconds end)
	self.ctx.Notify(player, L.M("egg.incubated", {icon = EC.Kinds[egg.Kind].Icon, s = seconds}))
	return true
end

-- 깨우기: 시간이 된 알 → 새 펫. 반환: 펫 데이터 (클라이언트 부화 연출에 보낸다)
function S:Hatch(player, id)
	local profile = self.ctx.Data:Get(player)
	if type(id) ~= "string" or not profile or not self:Throttle(player) then return nil end
	local egg = profile.Eggs and profile.Eggs[id]
	if not egg or not egg.HatchAt or os.time() < egg.HatchAt then return nil end
	if R.count(profile.Pets) >= P.CollectionLimit then
		self.ctx.Notify(player, L.M("egg.petsFull", {n = P.CollectionLimit}))
		return nil
	end
	local pet = Eggs.hatch(egg.Kind, self.Rng, EC, P, R)
	pet.Uid = Http:GenerateGUID(false)
	pet.CaughtAt, pet.CaughtRegion = os.time(), "Egg"
	local newSpecies = false
	self.ctx.Data:Mutate(player, function(data)
		data.Eggs[id] = nil
		data.Pets[pet.Uid] = pet
		local entry = data.Dex[pet.SpeciesId]
		newSpecies = not (entry and entry.Caught)
		data.Dex[pet.SpeciesId] = {Seen = true, Caught = true}
		-- 출전 칸이 비어 있으면 바로 넣어 준다 (다음 원정에 데려가게)
		if #data.Party < P.ActiveLimit then table.insert(data.Party, pet.Uid) end
	end)
	self.ctx.Data:Save(player)
	self.ctx.PetFX:FireClient(player, "Hatched", pet, newSpecies)
	return pet
end

function S:RemovePlayer(player)
	self.Last[player] = nil
end

return S
