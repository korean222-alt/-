--[[
	RescueService  (Phase 15)
	"바다로 떨어지면 죽는데 리스폰이 안 돼" 를 고친다.

	원인
	  · 바다는 장식 파트라 부딪히지 않는다 (CanCollide = false). 배에서 떨어진 사람은 물을 뚫고
	    끝없이 떨어지다가 한참 아래(FallenPartsDestroyHeight)에서 몸이 지워진다.
	  · 몸이 지워지는 순간 Humanoid 가 "죽음" 상태가 되지 못하면 Roblox 의 자동 부활이 오지 않는다.
	    (스트리밍 중인 서버에서 특히 잘 생긴다) 화면은 바다 밑에 멈춘 채로 남는다.

	고침
	  1. 물에 빠지는 순간(몸 중심이 GameConfig.Rescue.BelowY 아래) 가장 가까운 갑판 가운데로 건져 올린다.
	     죽지 않는다. 내 화면에는 "풍덩!" 이 뜬다 (WorldCue "Rescue").
	  2. 그래도 어떤 이유로든 죽었는데 RespawnTime 이 지나도 새 몸이 안 생기면 서버가 LoadCharacter 로 살린다.
	  3. 떨어진 몸이 지워지는 높이를 -140 으로 올려 두어, 혹시 빠져나가도 오래 떨어지지 않는다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local RESCUE = GameConfig.Rescue

local RescueService = {}
RescueService._started = false
RescueService._lastRescue = {} -- [Player] = os.clock()

local function cue()
	local folder = ReplicatedStorage.CursedBarrel:FindFirstChild(GameConfig.Remotes.Folder)
	return folder and folder:FindFirstChild(GameConfig.Remotes.WorldCue)
end

-- 가장 가까운 건져 올릴 자리 (앞뒤 z 가 가장 가까운 곳)
function RescueService.spotFor(position)
	local best, bestDistance = nil, math.huge
	for _, spot in ipairs(RESCUE.Spots) do
		local distance = math.abs(spot.Z - position.Z) + math.abs(spot.X - position.X) * 0.1
		if distance < bestDistance then
			best, bestDistance = spot, distance
		end
	end
	return best or Vector3.new(0, 6, 118)
end

-- 이 몸이 물에 빠졌나 (또는 배에서 너무 멀리 나갔나)
function RescueService.needsRescue(position)
	if position.Y < RESCUE.BelowY then
		return true
	end
	return math.abs(position.X) > RESCUE.FarXZ or math.abs(position.Z) > RESCUE.FarXZ
end

function RescueService:Rescue(player, root)
	local now = os.clock()
	if (self._lastRescue[player] or 0) > now - 0.5 then
		return false
	end
	self._lastRescue[player] = now
	local spot = RescueService.spotFor(root.Position)
	local character = root.Parent
	local look = Vector3.new(root.Position.X, spot.Y, root.Position.Z) - spot
	local facing = look.Magnitude > 0.1 and CFrame.lookAt(spot, spot - look.Unit) or CFrame.new(spot)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if character then
		character:PivotTo(facing)
	else
		root.CFrame = facing
	end
	local remote = cue()
	if remote then
		remote:FireClient(player, "Rescue", { at = spot })
	end
	return true
end

function RescueService:_watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		-- 자동 부활이 오지 않으면 서버가 살린다
		task.delay((Players.RespawnTime or 5) + RESCUE.RespawnSafety, function()
			if player.Parent == Players and player.Character == character then
				pcall(function()
					player:LoadCharacter()
				end)
			end
		end)
	end)
end

function RescueService:Start()
	if self._started or not RESCUE.Enabled then
		return
	end
	self._started = true
	pcall(function()
		workspace.FallenPartsDestroyHeight = RESCUE.FallenPartsDestroyHeight
	end)

	local function join(player)
		player.CharacterAdded:Connect(function(character)
			self:_watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(self._watchCharacter, self, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in ipairs(Players:GetPlayers()) do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._lastRescue[player] = nil
	end)

	task.spawn(function()
		while self._started do
			task.wait(RESCUE.Interval)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and not humanoid.SeatPart and RescueService.needsRescue(root.Position) then
					local ok, err = pcall(self.Rescue, self, player, root)
					if not ok then
						warn("[CursedBarrel] 바다에서 건지기 오류: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return RescueService
