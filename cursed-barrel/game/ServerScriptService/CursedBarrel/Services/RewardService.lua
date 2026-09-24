--[[
	RewardService  (Phase 13)
	출석판과 룰렛.

	출석판
	  · 들어온 날마다 한 칸씩 받는다. 하루 빠져도 처음으로 돌아가지 않는다. 7칸을 다 받으면 새 판.
	  · 버튼을 눌러 직접 받는다. (자동으로 주면 받은 줄도 모른다)
	  · VIP 는 코인이 2배. (VIP 패스를 사고 싶게 만드는 가장 눈에 띄는 자리)

	룰렛
	  · 하루에 한 번 무료로 돌린다. (이용권 · 로벅스 판매 없음 : 돈 주고 사는 뽑기가 아니다)
	  · 결과는 서버가 정하고, 클라이언트는 그 칸에 멈추는 연출만 한다.
	  · 확률표는 보여 주지 않는다 (Phase 15). 무료 룰렛이라 공개 의무가 없다. 유료로 바꾸면 다시 보여 줘야 한다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)

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
	ProfileService:_touch(player)
	return true, { day = index, coins = coins, vip = vip, full = index >= #ATTEND.Days }
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

-- 스킨 칸 : 아직 없는 코인 스킨 중 segment.minPrice ~ maxPrice 가격의 것 하나
function RewardService:_pickSkin(profile, segment)
	local pool = {}
	for kind, list in pairs(GameConfig.Skins) do
		if typeof(list) == "table" and profile.owned[kind] then
			for _, skin in ipairs(list) do
				if typeof(skin) == "table" and GameConfig.isCoinSkin(skin) and skin.price >= (segment.minPrice or 1)
					and skin.price <= (segment.maxPrice or math.huge) and not profile.owned[kind][skin.id] then
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

-- 하루에 한 번
function RewardService:Spin(player, today)
	if not ROULETTE.Enabled then
		return false, REJECT.NoSpins
	end
	local profile = ProfileService:Get(player)
	if not profile then
		return false, "자료를 불러오는 중입니다"
	end
	today = today or Utility.today()
	if profile.freeSpinDay == today then
		return false, REJECT.NoSpins
	end
	profile.freeSpinDay = today

	local index = self:_rollIndex()
	local segment = ROULETTE.Segments[index]
	local result = { index = index, id = segment.id, kind = segment.kind, amount = segment.amount }
	if segment.kind == "coins" then
		profile.coins += segment.amount
	elseif segment.kind == "skin" then
		local pick = self:_pickSkin(profile, segment)
		if pick then
			profile.owned[pick.kind][pick.skin.id] = true
			result.skinKind, result.skinId, result.skinName = pick.kind, pick.skin.id, pick.skin.name
			if GameConfig.Announce and GameConfig.Announce.RouletteRare and (segment.minPrice or 0) > 12000 then
				require(script.Parent.ShopService).announce(player, pick.skin, "roulette")
			end
		else
			profile.coins += segment.fallbackCoins or 0
			result.kind, result.amount = "coins", segment.fallbackCoins or 0
		end
	end
	profile.spinCount = (profile.spinCount or 0) + 1
	ProfileService:_touch(player)
	return true, result
end

--------------------------------------------------
-- 요청
--------------------------------------------------

--------------------------------------------------
-- Phase 16 : 그룹 가입 보상 (파란 철제 드럼)
--   Phase 16.1 : "사람을 믿지 말고 확인" → 서버가 그룹 가입을 직접 확인한 사람에게만 준다.
--     · Roblox 는 게임 서버가 "이 사람이 좋아요를 눌렀는지" 알 수 있는 방법을 주지 않는다
--       (좋아요 기록은 그 사람 본인 로그인으로만 볼 수 있고, 게임 서버는 roblox.com 에 요청할 수 없다).
--       사진 속 게임들도 실제로 확인하는 것은 그룹 가입뿐이다. 좋아요는 "부탁"으로만 적는다.
--     · 그룹 ID(ReleaseConfig.GroupId)가 없으면 확인할 것이 없으니 주지 않는다 ("notready").
--------------------------------------------------

local function groupId()
	local ok, release = pcall(require, Shared:WaitForChild("ReleaseConfig"))
	return ok and tonumber(release.GroupId) or 0
end
RewardService.groupId = groupId

-- 그룹에 들어 있는가. IsInGroup 은 한 서버에서 처음 물어본 값을 기억하므로(방금 가입해도 false),
-- 아니라고 하면 GetGroupsAsync 로 한 번 더 확인한다. 둘 다 실패하면 nil (잠시 뒤 다시).
function RewardService.isMember(player, group)
	local okCached, cached = pcall(function()
		return player:IsInGroup(group)
	end)
	if okCached and cached then
		return true
	end
	local okFresh, groups = pcall(function()
		return game:GetService("GroupService"):GetGroupsAsync(player.UserId)
	end)
	if okFresh and typeof(groups) == "table" then
		for _, info in ipairs(groups) do
			if tonumber(info.Id) == group then
				return true
			end
		end
		return false
	end
	if okCached then
		return false
	end
	return nil
end

function RewardService:ClaimLike(player)
	local like = GameConfig.LikeReward
	if not (like and like.Enabled) then
		return false, "지금은 받을 수 없어요"
	end
	local profile = ProfileService:Get(player)
	if not profile then
		return false, "자료를 불러오는 중입니다"
	end
	if profile.likeClaimed then
		return false, "이미 받았어요 ✔"
	end
	local group = groupId()
	if group <= 0 then
		return false, "notready"
	end
	local member = RewardService.isMember(player, group)
	if member == nil then
		return false, "잠시 뒤 다시 눌러 주세요"
	elseif not member then
		return false, "group"
	end
	profile.likeClaimed = true
	ProfileService:Grant(player, like.Kind, like.Skin) -- 저장 표시까지 한다
	if like.AutoEquip then
		ProfileService:Equip(player, like.Kind, like.Skin)
	end
	local skin = GameConfig.findSkin(like.Kind, like.Skin)
	return true, { skinName = skin and skin.name or like.Skin, kind = like.Kind, id = like.Skin }
end

function RewardService:_onRequest(player, action, arg)
	if not self._limiter:check(player.UserId) or typeof(action) ~= "string" then
		return
	end
	if action == "like" then
		local ok, result = self:ClaimLike(player)
		self._cue:FireClient(player, "like", ok, result)
		return
	elseif action == "code" then
		local CodeService = require(script.Parent.CodeService)
		local ok, message, coins = CodeService:Redeem(player, arg)
		self._cue:FireClient(player, "code", ok, { message = message, coins = coins })
		return
	end
	if action == "attend" then
		local ok, result = self:ClaimAttendance(player)
		self._cue:FireClient(player, "attend", ok, result)
	elseif action == "spin" then
		local ok, result = self:Spin(player)
		self._cue:FireClient(player, "spin", ok, result)
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
	request.OnServerEvent:Connect(function(player, action, arg)
		local ok, err = pcall(self._onRequest, self, player, action, arg)
		if not ok then
			warn("[CursedBarrel] 보상 요청 오류: " .. tostring(err))
		end
	end)

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
