--[[
	ShopService  (Phase 7)
	코인으로 스킨을 사고, 가진 스킨을 장착한다. 로벅스 상품도 여기서 받는다.

	지켜야 하는 것
	  · 가격과 소유 여부는 전부 서버가 판단한다. 클라이언트가 보내는 것은 "무엇을"까지다.
	  · 이미 가진 것을 또 사게 두지 않는다. (코인만 사라진다)
	  · 가지지 않은 스킨은 장착되지 않는다.
	  · 로벅스 상품은 PurchaseService 가 영수증을 확인한 뒤에야 지급된다.

	Phase 10
	  · VIP 게임패스 : 게임에서 버는 코인 +20%, 전용 칼, 머리 위 VIP 표시. 소유 확인은 서버가 한다.
	  · 스타터 팩 : 계정당 한 번 사는 개발자 상품. 코인과 전용 칼.
	  · VIP · 스타터 전용 스킨은 코인으로 살 수 없다.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)
local PurchaseService = require(script.Parent.PurchaseService)
local TableService = require(script.Parent.TableService)

local REJECT = GameConfig.RejectMessages
local PLAYER_ATTR = GameConfig.PlayerAttributes
local STARTER = GameConfig.Products.Starter
local VIP = GameConfig.Products.GamePasses.VIP

local ShopService = {}
ShopService._started = false
ShopService._cleaner = Utility.Cleaner.new()
ShopService._limiter = Utility.RateLimiter.new(0.2)
ShopService._lastSync = {} -- [Player] = 마지막으로 상태를 내려보낸 시각

local function remote(name)
	local folder = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild(GameConfig.Remotes.Folder)
	local found = folder:FindFirstChild(name)
	if not found then
		found = Instance.new("RemoteEvent")
		found.Name = name
		found.Parent = folder
	end
	return found
end

--------------------------------------------------
-- 클라이언트에게 보낼 상태 한 덩어리
--------------------------------------------------

local function skinEntry(kind, skin, owned, equipped)
	local rarity = GameConfig.rarityOf(skin)
	return {
		kind = kind,
		id = skin.id,
		name = skin.name,
		rarity = skin.rarity or "common",
		rarityLabel = rarity.label,
		rarityColor = rarity.color,
		price = tonumber(skin.price) or 0,
		robux = tonumber(skin.robux) or 0,
		vip = skin.vip == true,
		pack = skin.pack,
		owned = owned,
		equipped = equipped,
	}
end

-- "Knife/vip_cutlass" 같은 문자열을 종류와 id 로 나눈다.
local function splitSkin(text)
	if typeof(text) ~= "string" then
		return nil, nil
	end
	return text:match("^(%a+)/(.+)$")
end

function ShopService:BuildState(player)
	local profile = ProfileService:Get(player)
	if not profile then
		return nil
	end

	local catalog = {}
	for _, kind in ipairs({ "Knife", "Barrel", "Ghost", "Chair", "Elimination", "Victory", "Stab" }) do
		local list = {}
		for _, skin in ipairs(GameConfig.Skins[kind]) do
			table.insert(list, skinEntry(kind, skin, profile.owned[kind][skin.id] == true, profile.equipped[kind] == skin.id))
		end
		catalog[kind] = list
	end

	local coinPacks = {}
	for _, pack in ipairs(GameConfig.Products.Coins) do
		table.insert(coinPacks, {
			id = pack.id, name = pack.name, coins = pack.coins,
			robux = pack.robux, productId = pack.productId,
			ready = (tonumber(pack.productId) or 0) > 0,
		})
	end

	local vipReady = (tonumber(VIP.gamePassId) or 0) > 0
	local starterReady = (tonumber(STARTER.productId) or 0) > 0

	return {
		coins = profile.coins,
		loginStreak = profile.loginStreak or 0,
		vip = {
			name = VIP.name, robux = VIP.robux, blurb = VIP.blurb,
			owned = player:GetAttribute(PLAYER_ATTR.VIP) == true, ready = vipReady,
		},
		starter = {
			name = STARTER.name, robux = STARTER.robux, blurb = STARTER.blurb,
			owned = profile.starterBought == true, ready = starterReady,
		},
		level = GameConfig.levelOf(profile.wins, profile.games),
		wins = profile.wins,
		games = profile.games,
		streak = profile.streak,
		bestStreak = profile.bestStreak,
		catalog = catalog,
		coinPacks = coinPacks,
		quests = ProfileService:GetQuests(player),
		achievements = ProfileService:GetAchievements(player),
	}
end

--[[
	상태를 통째로 내려보낸다.

	★ 이 함수는 코인이 오를 때마다 불린다. 안전한 자리를 한 번 뽑을 때마다도 불린다.
	  목록 전체(스킨 21개 + 퀘스트 + 업적)를 매번 보내면 테이블 10개가 도는 서버에서
	  쓸데없는 트래픽이 된다. 그래서 말할 것이 있을 때(message)나 사람이 직접 요청했을 때가
	  아니면 2초에 한 번으로 묶는다.
]]
local SYNC_INTERVAL = 2

function ShopService:Sync(player, message, ok, force)
	if not force and not message then
		local last = self._lastSync[player]
		if last and (os.clock() - last) < SYNC_INTERVAL then
			return
		end
	end
	self._lastSync[player] = os.clock()

	local state = self:BuildState(player)
	if state then
		self._result:FireClient(player, ok ~= false, message, state)
	end
end

--------------------------------------------------
-- 코인으로 사기
--------------------------------------------------

function ShopService:Buy(player, kind, id)
    if not ProfileService:CanPurchase(player) then return false,"저장 연결 후 구매할 수 있습니다 / Purchases require saved data" end
	if not GameConfig.Skins.PlayerAttributes[kind] then
		return false, REJECT.BadSlot
	end
	local skin = GameConfig.findSkin(kind, id)
	if not skin or skin.id ~= id then
		return false, REJECT.BadSlot
	end
	if ProfileService:Owns(player, kind, id) then
		return false, REJECT.AlreadyOwned
	end

	if skin.vip then
		return false, REJECT.VipOnly
	end
	if skin.pack then
		return false, REJECT.PackOnly
	end

	local price = tonumber(skin.price) or 0
	if price <= 0 then
		-- 가격이 없는 스킨은 로벅스 전용이거나 기본 지급품이다.
		if skin.robux then
			return false, REJECT.RobuxOnly
		end
		ProfileService:Grant(player, kind, id)
		return true, ("%s 을(를) 받았습니다"):format(skin.name)
	end

	if not ProfileService:Spend(player, price) then
		return false, REJECT.NoCoins
	end

	ProfileService:Grant(player, kind, id)
	GameConfig.log(("%s 가 %s/%s 를 %d코인에 구매"):format(player.Name, kind, id, price))
	return true, ("%s 구매 완료 (-%s 코인)"):format(skin.name, Utility.comma(price))
end

--------------------------------------------------
-- 장착
--------------------------------------------------

function ShopService:Equip(player, kind, id)
	local ok, reason = ProfileService:Equip(player, kind, id)
	if not ok then
		return false, reason
	end

	-- 통 스킨은 테이블 하나에 하나만 적용된다.
	-- 지금 앉아 있는 테이블이 있으면 그 자리에서 다시 고르게 한다.
	if kind == "Barrel" then
		local gameTable = TableService:GetTableOfPlayer(player)
		if gameTable then
			gameTable:RefreshBarrelSkin()
		end
	end

	local skin = GameConfig.findSkin(kind, id)
	return true, ("%s 장착"):format(skin and skin.name or id)
end

--------------------------------------------------
-- 로벅스 상품
--------------------------------------------------

function ShopService:_registerProducts()
	for _, pack in ipairs(GameConfig.Products.Coins) do
		PurchaseService:Register(pack.productId, function(profile)
			profile.coins = profile.coins + pack.coins
			return true
		end)
	end
	for _, entry in ipairs(GameConfig.Products.Skins) do
		local kind, id = splitSkin(entry.skin)
		PurchaseService:Register(entry.productId, function(profile)
			if not kind or not profile.owned[kind] or GameConfig.findSkin(kind, id).id ~= id then
				return false
			end
			profile.owned[kind][id] = true
			return true
		end)
	end

	-- 스타터 팩. 이미 산 사람이 영수증을 또 보내오면(다른 서버에서 동시에 샀을 때 등) 코인만 다시 준다.
	-- 결제는 이미 끝났으므로 거절하지 않는다. 가게에서는 산 뒤로 버튼이 사라진다.
	local starterKind, starterId = splitSkin(STARTER.skin)
	PurchaseService:Register(STARTER.productId, function(profile)
		profile.coins = profile.coins + (tonumber(STARTER.coins) or 0)
		if starterKind and profile.owned[starterKind] and GameConfig.findSkin(starterKind, starterId).id == starterId then
			profile.owned[starterKind][starterId] = true
		end
		profile.starterBought = true
		return true
	end)
end

--------------------------------------------------
-- VIP 게임패스 (Phase 10)
--------------------------------------------------

function ShopService:_setVip(player, owned)
	if player.Parent ~= Players then
		return
	end
	if owned then
		player:SetAttribute(PLAYER_ATTR.VIP, true)
		self:_grantVipSkin(player)
	elseif player:GetAttribute(PLAYER_ATTR.VIP) == nil then
		player:SetAttribute(PLAYER_ATTR.VIP, false)
	end
end

-- 자료를 다 읽은 뒤에만 줄 수 있다. 소유 확인이 먼저 끝나면 ProfileChanged 에서 다시 부른다.
function ShopService:_grantVipSkin(player)
	if player:GetAttribute(PLAYER_ATTR.VIP) ~= true then
		return
	end
	local kind, id = splitSkin(VIP.skin)
	if kind and ProfileService:Get(player) and not ProfileService:Owns(player, kind, id) then
		ProfileService:Grant(player, kind, id)
	end
end

function ShopService:_checkVip(player)
	local passId = tonumber(VIP.gamePassId) or 0
	if passId <= 0 then
		return
	end
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			if ok then
				self:_setVip(player, owned == true)
				return
			end
			task.wait(attempt * 2)
		end
	end)
end

-- 클라이언트가 로벅스 구매창을 띄우기 전에 "그 상품이 진짜 있는지" 서버가 확인한다.
function ShopService:_robuxProductFor(kind, id)
	for _, entry in ipairs(GameConfig.Products.Skins) do
		if entry.skin == (kind .. "/" .. id) then
			return tonumber(entry.productId) or 0
		end
	end
	return 0
end

--------------------------------------------------
-- 요청 처리
--------------------------------------------------

function ShopService:_onRequest(player, action, kind, id)
	if not self._limiter:check(player.UserId) then
		return
	end
	if typeof(action) ~= "string" or (kind~=nil and typeof(kind)~="string") or (id~=nil and typeof(id)~="string") then
		return
	end

	if action == "sync" then
		self:Sync(player, nil, true, true)
		return
	end

	if action == "buy" then
		local ok, message = self:Buy(player, kind, id)
		self:Sync(player, message, ok)
		return
	end

	if action == "equip" then
		local ok, message = self:Equip(player, kind, id)
		self:Sync(player, message, ok)
		return
	end

	if action == "vip" then
		local passId = tonumber(VIP.gamePassId) or 0
		if passId <= 0 then
			self:Sync(player, "VIP 패스는 아직 준비 중입니다", false)
			return
		end
		if player:GetAttribute(PLAYER_ATTR.VIP) == true then
			self:Sync(player, "이미 VIP 입니다", false)
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
		if not ok then
			warn("[CursedBarrel] 게임패스 구매창을 띄우지 못했습니다: " .. tostring(err))
		end
		return
	end

	if action == "robux" then
		if not ProfileService:CanPurchase(player) then
			self:Sync(player, "저장 연결이 필요합니다", false)
			return
		end
		if typeof(kind) ~= "string" or typeof(id) ~= "string" then
			return
		end
		if kind ~= "coins" and kind ~= "starter" and ProfileService:Owns(player, kind, id) then
			return
		end
		-- kind/id 는 스킨, 또는 kind == "coins" 이면 코인 묶음 id, kind == "starter" 면 스타터 팩
		local productId = 0
		if kind == "starter" then
			local profile = ProfileService:Get(player)
			if profile and profile.starterBought then
				self:Sync(player, "스타터 팩은 계정당 한 번만 살 수 있습니다", false)
				return
			end
			productId = tonumber(STARTER.productId) or 0
		elseif kind == "coins" then
			for _, pack in ipairs(GameConfig.Products.Coins) do
				if pack.id == id then
					productId = tonumber(pack.productId) or 0
				end
			end
		else
			productId = self:_robuxProductFor(kind, tostring(id))
		end

		if productId <= 0 then
			self:Sync(player, "이 상품은 아직 준비 중입니다", false)
			return
		end

		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[CursedBarrel] 구매창을 띄우지 못했습니다: " .. tostring(err))
		end
		return
	end

	if action == "claimQuest" then
		local ok, result = ProfileService:ClaimQuest(player, tostring(kind))
		self:Sync(player, ok and ("퀘스트 완료 · +%s 코인"):format(Utility.comma(result)) or tostring(result), ok)
		return
	end
end

function ShopService:Start()
	if self._started then
		return
	end
	self._started = true

	self._request = remote(GameConfig.Remotes.ShopRequest)
	self._result = remote(GameConfig.Remotes.ShopResult)

	self:_registerProducts()

	self._cleaner:add(self._request.OnServerEvent:Connect(function(player, action, kind, id)
		local ok, err = pcall(function()
			self:_onRequest(player, action, kind, id)
		end)
		if not ok then
			warn("[CursedBarrel] 상점 요청 처리 중 오류: " .. tostring(err))
		end
	end))

	-- 자료를 다 읽으면 한 번 내려보낸다.
	self._cleaner:add(ProfileService.ProfileChanged:Connect(function(player)
		self:_grantVipSkin(player)
		self:Sync(player, nil, true)
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		self._limiter:forget(player.UserId)
		self._lastSync[player] = nil
	end))

	-- VIP 게임패스
	self._cleaner:add(Players.PlayerAdded:Connect(function(player)
		self:_checkVip(player)
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		self:_checkVip(player)
	end
	self._cleaner:add(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == (tonumber(VIP.gamePassId) or 0) and passId > 0 then
			self:_setVip(player, true)
			self:Sync(player, VIP.name .. " 구매 완료! 이제 코인을 더 법니다", true)
		end
	end))

	if RunService:IsStudio() then
		GameConfig.log("상점: Studio 에서는 로벅스 상품 ID 가 0 이면 '준비 중'으로만 보입니다.")
	end

	GameConfig.log("ShopService 시작 완료")
end

return ShopService
