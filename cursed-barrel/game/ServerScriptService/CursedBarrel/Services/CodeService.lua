--[[
	CodeService  (Phase 16)
	🎟 코드 입력. 오른쪽 "코드" 버튼 → 코드를 적고 「확인」.

	★ 코드 목록은 서버에만 있다 (ServerScriptService). 클라이언트는 목록을 볼 수 없다.

	코드 하나 = { coins = 줄 코인, developer = 개발자 계정만, repeatable = 여러 번 쓸 수 있는가, expires = 끝나는 시각(선택) }
	  · 보통 코드는 계정당 한 번 (profile.codes 에 적어 둔다).
	  · developer = true 인 코드는 개발자 계정에서만 된다. 다른 사람이 코드를 알아도 "없는 코드" 로 보인다.
	    개발자 = Studio · 게임 주인(개인 게임이면 만든 사람, 그룹 게임이면 그룹 주인 · 관리자 순위 254 이상)
	            · 아래 DeveloperUserIds 에 적은 계정
	  · 개발자 코드를 쓴 계정은 profile.devTester = true 가 되어 랭킹에 올라가지 않는다.
	  · 코드 글자는 대소문자 · 앞뒤 빈칸을 가리지 않는다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)

local CodeService = {}

CodeService.Codes = {
	-- 개발자 스킨 시험용 : 쓸 때마다 999,999 코인 (개발자 계정에서만)
	gnsdl23091 = { coins = 999999, developer = true, repeatable = true },
	-- 누구나 한 번 : 출시 기념 (바꾸거나 지워도 된다)
	cursedbarrel = { coins = 1500 },
}

-- 개발자 계정을 더 넣으려면 UserId 숫자를 적는다 (예: { 12345678 })
CodeService.DeveloperUserIds = {}

CodeService.MaxLength = 32

function CodeService.normalize(text)
	if typeof(text) ~= "string" then
		return nil
	end
	local code = string.lower((text:gsub("^%s+", ""):gsub("%s+$", "")))
	if code == "" or #code > CodeService.MaxLength then
		return nil
	end
	return code
end

function CodeService.isDeveloper(player)
	if RunService:IsStudio() then
		return true
	end
	if table.find(CodeService.DeveloperUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and (tonumber(rank) or 0) >= 254
	end
	return false
end

-- 돌려주는 값 : ok, 메시지, 받은 코인
function CodeService:Redeem(player, text, now)
	local code = CodeService.normalize(text)
	if not code then
		return false, "코드를 적어 주세요", 0
	end
	local profile = ProfileService:Get(player)
	if not profile then
		return false, "자료를 불러오는 중입니다", 0
	end
	local entry = self.Codes[code]
	if not entry or (entry.developer and not CodeService.isDeveloper(player)) then
		return false, "없는 코드예요", 0
	end
	if entry.expires and (now or os.time()) > entry.expires then
		return false, "기간이 끝난 코드예요", 0
	end
	if not entry.repeatable and profile.codes[code] then
		return false, "이미 쓴 코드예요", 0
	end
	local coins = math.max(0, math.floor(tonumber(entry.coins) or 0))
	-- VIP 배율 없이 적힌 그대로 준다
	profile.coins += coins
	if not entry.repeatable then
		profile.codes[code] = true
	end
	if entry.developer then
		profile.devTester = true
	end
	ProfileService:_touch(player)
	GameConfig.log(("코드 %s · %s · +%d 코인"):format(code, player.Name, coins))
	return true, ("🎉 🪙 %s 코인!"):format(Utility.comma(coins)), coins
end

return CodeService
