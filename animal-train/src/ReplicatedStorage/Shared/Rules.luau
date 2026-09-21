--!strict
-- 규칙 계산 (서버·클라이언트 공용). 값 자체는 Config 에 있습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Rules = {}

function Rules.maxTrain(trainLevel: number): number
	return Config.Train.BaseMaxLength + trainLevel * Config.Upgrades.Train.LengthPerLevel
end

function Rules.pickupRadius(magnetLevel: number): number
	return Config.Pickup.BaseRadius + magnetLevel * Config.Pickup.MagnetBonusPerLevel
end

function Rules.walkSpeed(speedLevel: number): number
	return Config.Player.BaseWalkSpeed + speedLevel * Config.Player.SpeedPerLevel
end

function Rules.maxLevel(kind: string): number
	local info = Config.Upgrades[kind]
	return info and info.MaxLevel or 0
end

-- 다음 단계 가격. 더 살 수 없으면 nil.
function Rules.nextPrice(kind: string, currentLevel: number): number?
	local info = Config.Upgrades[kind]
	if not info then
		return nil
	end
	if currentLevel >= info.MaxLevel then
		return nil
	end
	return info.Prices[currentLevel + 1]
end

function Rules.islandReward(species: string): number
	local info = Config.Animals[species]
	return info and info.Reward or 1
end

return Rules
