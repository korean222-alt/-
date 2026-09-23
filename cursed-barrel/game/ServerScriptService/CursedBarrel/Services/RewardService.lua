--[[
	RewardService  (Phase 13)
	출석판과 룰렛.

	출석판
	  · 들어온 날마다 한 칸씩 받는다. 하루 빠져도 처음으로 돌아가지 않는다. 7칸을 다 받으면 새 판.
	  · 버튼을 눌러 직접 받는다. (자동으로 주면 받은 줄도 모른다)
	  · VIP 는 코인이 2배. (VIP 패스를 사고 싶게 만드는 가장 눈에 띄는 자리)

	룰렛
	  · 하루 한 번 무료. 이용권(출석 · 룰렛 칸 · 구매)으로 더 돌린다.
	  · 결과는 서버가 정하고, 클라이언트는 그 칸에 멈추는 연출만 한다.
	  · 로벅스 이용권은 "무작위 보상"이므로 확률표를 항상 보여 주고,
	    PolicyService 가 막은 나라(ArePaidRandomItemsRestricted)에서는 팔지 않는다.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)
local PurchaseService = require(script.Parent.PurchaseService)

local ATTEND = GameConfig.Attendance
local ROULETTE = GameConfig.Roulette
local REJECT = GameConfig.RejectMessages

local RewardService = {}
RewardService._started = false
RewardService._limiter = Utility.RateLimiter.new(0.4)
RewardService._random = Random.new()
RewardService._cue = nil

--------------------------------------------------
-- 출석판
--------------------------------------------------

-- 지금 받을 칸 (1~7)
function RewardService.nextDay(profile)
	return (profile.attendCount or 0) % #ATTEND.Days + 1
end

function RewardService:ClaimAttendance(player, today)
	if not ATTEND.Enabled then
		return false, REJECT.AlreadyClaimed
	end
	local profile = ProfileService:Get(player)
	if not profile then
		return false, "자료를 불러오는 중입니다"
	end
	today = today or Utility.today()
	if profile.attendDay == today then
		return false, REJECT.AlreadyClaimed
	end
	local index = RewardService.nextDay(profile)
	local reward = ATTEND.Days[index]
	local coins = tonumber(reward.coins) or 0
	local vip = player:GetAttribute(GameConfig.PlayerAttributes.VIP) == true
	if vip then
		coins = math.floor(coins * (ATTEND.VipMultiplier or 1))
	end
	profile.attendDay = today
	profile.attendCount = index >= #ATTEND.Days and 0 or index
	profile.coins += coins
	profile.spins = (profile.spins or 0) + (tonumber(reward.spins) or 0)
	ProfileService:_touch(player)
	return true, { day = index, coins = coins, spins = reward.spins or 0, vip = vip, full = index >= #ATTEND.Days }
end

--------------------------------------------------
-- 룰렛
--------------------------------------------------

function RewardService:_rollIndex()
	local roll = self._random:NextNumber() * GameConfig.rouletteTotalWeight()
	local acc = 0
	for index, segment in ipairs(ROULETTE.Segments) do
		acc += segment.weight
		if roll < acc then
			return index
		end
	end
	return #ROULETTE.Segments
end

-- 스킨 칸 : 아직 없는, 코인으로 살 수 있는 싼 스킨 하나
function RewardService:_pickSkin(profile)
	local pool = {}
	for kind, list in pairs(GameConfig.Skins) do
		if typeof(list) == "table" and profile.owned[kind] then
			for _, skin in ipairs(list) do
				if typeof(skin) == "table" and GameConfig.isCoinSkin(skin) and skin.price <= ROULETTE.SkinMaxPrice and not profile.owned[kind][skin.id] then
					table.insert(pool, { kind = kind, skin = skin })
				end
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		return a.kind .. a.skin.id < b.kind .. b.skin.id
	end)
	return pool[self._random:NextInteger(1, #pool)]
end

-- useFree : 오늘 무료 돌리기를 먼저 쓴다. 없으면 이용권.
function RewardService:Spin(player, today)
	if not ROULETTE.Enabled then
		return false, REJECT.NoSpins
	end
	local profile = ProfileService:Get(player)
	if not profile then
		return false, "자료를 불러오는 중입니다"
	end
	today = today or Utility.today()
	local usedFree = false
	if profile.freeSpinDay ~= today then
		profile.freeSpinDay = today
		usedFree = true
	elseif (profile.spins or 0) > 0 then
		profile.spins -= 1
	else
		return false, REJECT.NoSpins
	end

	local index = self:_rollIndex()
	local segment = ROULETTE.Segments[index]
	local result = { index = index, id = segment.id, kind = segment.kind, amount = segment.amount, free = usedFree }
	if segment.kind == "coins" then
		profile.coins += segment.amount
	elseif segment.kind == "spins" then
		profile.spins = (profile.spins or 0) + segment.amount
	elseif segment.kind == "skin" then
		local pick = self:_pickSkin(profile)
		if pick then
			profile.owned[pick.kind][pick.skin.id] = true
			result.skinKind, result.skinId, result.skinName = pick.kind, pick.skin.id, pick.skin.name
		else
			profile.coins += ROULETTE.SkinFallbackCoins
			result.kind, result.amount = "coins", ROULETTE.SkinFallbackCoins
		end
	end
	profile.spinCount = (profile.spinCount or 0) + 1
	ProfileService:_touch(player)
	return true, result
end

function RewardService:_checkPolicy(player)
	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if player.Parent ~= Players then
			return
		end
		-- 확인을 못 하면 막힌 것으로 본다 (안전한 쪽)
		player:SetAttribute("PaidRandomRestricted", not ok or typeof(info) ~= "table" or info.ArePaidRandomItemsRestricted ~= false)
	end)
end

--------------------------------------------------
-- 요청
--------------------------------------------------

function RewardService:_onRequest(player, action)
	if not self._limiter:check(player.UserId) or typeof(action) ~= "string" then
		return
	end
	if action == "attend" then
		local ok, result = self:ClaimAttendance(player)
		self._cue:FireClient(player, "attend", ok, result)
	elseif action == "spin" then
		local ok, result = self:Spin(player)
		self._cue:FireClient(player, "spin", ok, result)
	elseif action == "buySpins" then
		local pack = ROULETTE.SpinPack
		local productId = tonumber(pack.productId) or 0
		if player:GetAttribute("PaidRandomRestricted") ~= false then
			self._cue:FireClient(player, "notice", false, REJECT.PaidRandomRestricted)
		elseif productId <= 0 or not ProfileService:CanPurchase(player) then
			self._cue:FireClient(player, "notice", false, "아직 준비 중입니다")
		else
			pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, productId)
		end
	end
end

function RewardService:Start()
	if self._started then
		return
	end
	self._started = true
	local folder = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild(GameConfig.Remotes.Folder)
	local function remote(name)
		local found = folder:FindFirstChild(name)
		if not found then
			found = Instance.new("RemoteEvent")
			found.Name = name
			found.Parent = folder
		end
		return found
	end
	local request = remote(GameConfig.Remotes.Reward)
	self._cue = remote(GameConfig.Remotes.RewardCue)
	request.OnServerEvent:Connect(function(player, action)
		local ok, err = pcall(self._onRequest, self, player, action)
		if not ok then
			warn("[CursedBarrel] 보상 요청 오류: " .. tostring(err))
		end
	end)

	local pack = ROULETTE.SpinPack
	PurchaseService:Register(pack.productId, function(profile)
		profile.spins = (profile.spins or 0) + pack.spins
		return true
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_checkPolicy(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_checkPolicy(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._limiter:forget(player.UserId)
	end)

	-- 자정(UTC)이 지나면 버튼 위 빨간 점을 다시 켠다
	task.spawn(function()
		while self._started do
			task.wait(60)
			local today = Utility.today()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = ProfileService:Get(player)
				if profile then
					player:SetAttribute("AttendReady", ATTEND.Enabled and profile.attendDay ~= today)
					player:SetAttribute("FreeSpin", ROULETTE.Enabled and profile.freeSpinDay ~= today)
				end
			end
		end
	end)
	GameConfig.log("RewardService 시작 완료 (출석판 · 룰렛)")
end

return RewardService
