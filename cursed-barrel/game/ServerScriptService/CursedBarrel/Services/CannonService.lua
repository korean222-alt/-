--[[
	CannonService  (Phase 12)
	뱃전 대포로 크라켄을 쏘는 미니게임.

	· 대포(Cannon_<side>_<z>)마다 "대포 쏘기" 프롬프트를 단다. 누르면 그 사람이 대포를 잡는다. (한 대포에 한 명)
	· 클라이언트가 보낸 것은 "발사 방향" 하나뿐이다. 맞았는지는 서버가 KrakenTargets 로 다시 계산한다.
	  (포구 위치 · 방향 범위 · 재장전 · 대포와의 거리까지 서버가 확인한다)
	· 평소에는 맞힐 때마다 코인 몇 개 (하루 상한). 습격 중에는 크라켄 체력을 깎는다.
	· 테이블에 앉아 있는 사람은 대포를 잡을 수 없다. 대포에서 멀어지거나 오래 안 쏘면 자동으로 내린다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))
local KrakenTargets = require(Shared:WaitForChild("KrakenTargets"))

local ProfileService = require(script.Parent.ProfileService)
local TableService = require(script.Parent.TableService)
local WorldService = require(script.Parent.WorldService)

local CANNON = GameConfig.Cannon
local PLAYER_ATTR = GameConfig.PlayerAttributes

local CannonService = {}
CannonService._started = false
CannonService.cannons = {} -- [id] = { id, model, tube, side, muzzle, outward, occupant }
CannonService.manning = {} -- [Player] = cannon
CannonService.lastShot = {} -- [Player] = os.clock()
CannonService._cue = nil
CannonService._request = nil

local function remote(name)
	local folder = ReplicatedStorage.CursedBarrel:WaitForChild(GameConfig.Remotes.Folder)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

--------------------------------------------------
-- 대포 찾기
--------------------------------------------------

function CannonService:_register(model)
	local tube = model:FindFirstChild("CannonTube", true) -- Phase 14 : 포신 장식과 함께 Barrel 모델 안에 있다
	if not tube or not tube:IsA("BasePart") then
		return
	end
	local side = tube.Position.X < 0 and -1 or 1
	local outward = Vector3.new(side, 0, 0)
	local id = model.Name
	local cannon = {
		id = id,
		model = model,
		tube = tube,
		side = side,
		outward = outward,
		muzzle = tube.Position + outward * (tube.Size.X * 0.5 + 0.4),
		occupant = nil,
	}
	self.cannons[id] = cannon
	model:SetAttribute("CannonId", id)
	model:SetAttribute("CannonSide", side)

	local prompt = tube:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "CannonPrompt"
	prompt.ActionText = "대포 쏘기"
	prompt.ObjectText = "" -- 부제목 없음
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CANNON.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = tube
	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(self.Man, self, player, id)
		if not ok then
			warn("[CursedBarrel] 대포 잡기 오류: " .. tostring(err))
		end
	end)
end

function CannonService:_scan()
	local root = workspace:FindFirstChild("Lobby")
	root = root and root:FindFirstChild("PlayableGalleon") or workspace
	for _, model in ipairs(root:GetDescendants()) do
		if model:IsA("Model") and model.Name:match("^Cannon_") and not self.cannons[model.Name] then
			self:_register(model)
		end
	end
end

--------------------------------------------------
-- 잡기 · 내리기
--------------------------------------------------

local function rootOf(player)
	local humanoid = Utility.getHumanoid(player)
	return humanoid and humanoid.RootPart, humanoid
end

function CannonService:Man(player, id)
	local cannon = self.cannons[id]
	if not cannon or not CANNON.Enabled then
		return false
	end
	if TableService:GetTableOfPlayer(player) then
		return false -- 테이블에 앉은 사람은 대포를 잡지 않는다
	end
	local root, humanoid = rootOf(player)
	if not root or not humanoid or humanoid.SeatPart then
		return false
	end
	if (root.Position - cannon.tube.Position).Magnitude > CANNON.PromptDistance + 6 then
		return false
	end
	local other = cannon.occupant
	if other and other ~= player and self.manning[other] == cannon then
		local otherRoot = rootOf(other)
		if otherRoot and (otherRoot.Position - cannon.tube.Position).Magnitude <= CANNON.LeaveDistance then
			self._cue:FireClient(player, { kind = "busy", cannon = id, name = other.DisplayName or other.Name })
			return false
		end
	end
	self:Leave(player)
	if other and other ~= player then
		self:Leave(other)
	end
	cannon.occupant = player
	cannon.lastActive = os.clock()
	self.manning[player] = cannon
	player:SetAttribute(PLAYER_ATTR.CannonId, id)
	self._cue:FireClient(player, { kind = "manned", cannon = id, muzzle = cannon.muzzle, outward = cannon.outward })
	return true
end

function CannonService:Leave(player)
	local cannon = self.manning[player]
	self.manning[player] = nil
	if cannon and cannon.occupant == player then
		cannon.occupant = nil
	end
	if player.Parent == Players and player:GetAttribute(PLAYER_ATTR.CannonId) ~= nil then
		player:SetAttribute(PLAYER_ATTR.CannonId, nil)
	end
end

--------------------------------------------------
-- 발사
--------------------------------------------------

-- 발사 방향이 이 대포로 쏠 수 있는 방향인가
function CannonService.validDirection(cannon, dir)
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	local m = dir.Magnitude
	if m ~= m or m < 0.5 or m > 2 or m == math.huge then
		return nil
	end
	dir = dir / m
	if dir.Y < -0.6 or dir.Y > 0.9 then
		return nil
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.2 then
		return nil
	end
	local angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(cannon.outward), -1, 1)))
	if angle > CANNON.MaxAngle then
		return nil
	end
	return dir
end

-- 오늘 대포로 번 코인 (평소에만. 습격 보상은 따로다)
function CannonService:_payHit(player, coins)
	local profile = ProfileService:Get(player)
	if not profile then
		return 0
	end
	local today = Utility.today()
	if profile.cannonDay ~= today then
		profile.cannonDay = today
		profile.cannonCoins = 0
	end
	local room = math.max(0, CANNON.DailyCoinCap - (profile.cannonCoins or 0))
	local pay = math.min(room, coins)
	profile.cannonCoins = (profile.cannonCoins or 0) + pay
	ProfileService:Award(player, pay, "cannonHits")
	return pay
end

function CannonService:Fire(player, direction, now)
	now = now or GameConfig.now()
	local cannon = self.manning[player]
	if not cannon or cannon.occupant ~= player then
		return nil, "대포를 먼저 잡으세요"
	end
	local root = rootOf(player)
	if not root or (root.Position - cannon.tube.Position).Magnitude > CANNON.LeaveDistance then
		self:Leave(player)
		return nil, "대포에서 너무 멀어졌습니다"
	end
	local last = self.lastShot[player]
	if last and os.clock() - last < CANNON.Cooldown - 0.05 then
		return nil, "재장전 중"
	end
	local dir = CannonService.validDirection(cannon, direction)
	if not dir then
		return nil, "그쪽으로는 쏠 수 없습니다"
	end
	self.lastShot[player] = os.clock()
	cannon.lastActive = os.clock()

	local hit = KrakenTargets.findHit(cannon.muzzle, dir, now, {
		amp = WorldService:Agitation(),
		rise = WorldService:RaidRise(),
		slams = WorldService:ActiveSlams(),
		armRadius = CANNON.TargetRadius,
		eyeRadius = CANNON.EyeRadius,
		slamRadius = CANNON.SlamRadius,
		range = CANNON.Range,
	})

	local result = {
		kind = "shot",
		cannon = cannon.id,
		muzzle = cannon.muzzle,
		dir = dir,
		userId = player.UserId,
		name = player.DisplayName or player.Name,
	}
	if hit then
		result.hit = hit.kind
		result.index = hit.index
		result.point = hit.point
		if WorldService:IsRaidActive() then
			result.damage = WorldService:Damage(player, hit.kind, hit.kind == "slam" and hit.index or nil)
			ProfileService:Award(player, 0, "cannonHits")
		else
			result.coins = self:_payHit(player, hit.kind == "eye" and CANNON.EyeCoins or CANNON.CoinsPerHit)
		end
	else
		result.point = KrakenTargets.splashPoint(cannon.muzzle, dir, CANNON.Range)
	end
	self._cue:FireAllClients(result)
	return result, nil
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function CannonService:Start()
	if self._started then
		return
	end
	self._started = true
	self._cue = remote(GameConfig.Remotes.CannonCue)
	self._request = remote(GameConfig.Remotes.CannonRequest)
	if not CANNON.Enabled then
		return
	end
	self:_scan()

	local limiter = Utility.RateLimiter.new(0.2)
	self._request.OnServerEvent:Connect(function(player, action, direction)
		if not limiter:check(player.UserId) then
			return
		end
		local ok, err = pcall(function()
			if action == "fire" then
				local _, why = self:Fire(player, direction)
				if why then
					self._cue:FireClient(player, { kind = "deny", message = why })
				end
			elseif action == "leave" then
				self:Leave(player)
				self._cue:FireClient(player, { kind = "left" })
			end
		end)
		if not ok then
			warn("[CursedBarrel] 대포 요청 오류: " .. tostring(err))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:Leave(player)
		self.lastShot[player] = nil
		limiter:forget(player.UserId)
	end)

	-- 멀어졌거나 테이블에 앉았거나 오래 안 쏜 사람은 내린다
	task.spawn(function()
		while self._started do
			task.wait(1)
			for player, cannon in pairs(self.manning) do
				local root = rootOf(player)
				local far = not root or (root.Position - cannon.tube.Position).Magnitude > CANNON.LeaveDistance
				local idle = os.clock() - (cannon.lastActive or 0) > CANNON.IdleTimeout
				if player.Parent ~= Players or far or idle or TableService:GetTableOfPlayer(player) then
					self:Leave(player)
					if player.Parent == Players then
						self._cue:FireClient(player, { kind = "left" })
					end
				end
			end
		end
	end)

	GameConfig.log(("CannonService 시작 · 대포 %d문"):format((function()
		local n = 0
		for _ in pairs(self.cannons) do
			n += 1
		end
		return n
	end)()))
end

return CannonService
