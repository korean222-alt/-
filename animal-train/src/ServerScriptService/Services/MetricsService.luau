-- 12단계 : "10초 테스트" 자동 측정.
-- Studio 에서 플레이할 때 출력 창에 걸린 시간을 찍어 줍니다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)

local MetricsService = {}

local marks = {}

local function cheapestUpgradePrice()
	local cheapest = math.huge
	for _, kind in ipairs(Config.Upgrades.Order) do
		local price = Rules.nextPrice(kind, 0)
		if price and price < cheapest then
			cheapest = price
		end
	end
	return cheapest
end

local function report(player, label, target)
	local mark = marks[player]
	if not mark then
		return
	end
	local seconds = os.clock() - mark.joined
	local elapsed = string.format("%.1f초", seconds)
	local judge = seconds <= target and "목표 안에 들어옴 ✅" or ("목표(" .. target .. "초) 초과 ⚠️")
	print(string.format("[측정] %s · %s: %s (%s)", player.Name, label, elapsed, judge))
end

function MetricsService.Start()
	local function watch(player)
		marks[player] = { joined = os.clock() }
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		marks[player] = nil
	end)

	AnimalService.onTrainChanged(function(player)
		local mark = marks[player]
		if mark and not mark.firstAnimal and AnimalService.trainLength(player) > 0 then
			mark.firstAnimal = true
			report(player, "첫 동물 만나기", 10)
		end
	end)

	DataService.onChanged(function(player)
		local mark = marks[player]
		local data = DataService.get(player)
		if not mark or not data then
			return
		end
		if not mark.firstStar and data.totalStars > 0 then
			mark.firstStar = true
			report(player, "첫 별 받기", 60)
		end
		if not mark.firstUpgrade and data.stars >= cheapestUpgradePrice() then
			mark.firstUpgrade = true
			report(player, "첫 업그레이드 가능", 180)
		end
	end)

	if Config.Debug then
		print("[측정] 시작 (접속 → 첫 동물 / 첫 별 / 첫 업그레이드 시간을 잽니다)")
	end
end

return MetricsService
