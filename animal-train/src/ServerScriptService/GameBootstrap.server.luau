-- 서버 시작점. 서비스들을 정해진 순서로 켭니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")

local order = {
	"Effects", -- 리모트와 연출 먼저
	"DataService", -- 저장 (다른 서비스가 별을 주기 전에)
	"WorldService", -- 섬과 농장
	"AnimalService", -- 동물과 기차
	"FarmService", -- 배달과 별
	"GateService", -- 별 문
	"ShopService", -- 업그레이드
	"FoxService", -- NPC 여우
	"StateService", -- 화면에 보낼 상태
	"MetricsService", -- 시간 측정 (Studio 확인용)
}

print("[졸졸 동물 기차] 서버 시작")

local loaded = {}
for _, name in ipairs(order) do
	local moduleScript = Services:FindFirstChild(name)
	if not moduleScript then
		warn("[졸졸 동물 기차] 스크립트를 찾을 수 없음: " .. name)
	else
		local service = require(moduleScript)
		loaded[name] = service
		if type(service.Start) == "function" then
			local ok, err = xpcall(service.Start, function(message)
				return tostring(message) .. "\n" .. debug.traceback()
			end)
			if not ok then
				warn("[졸졸 동물 기차] " .. name .. " 시작 실패:\n" .. tostring(err))
			end
		end
	end
end

-- 물에 빠질 때 소리 (WorldService ↔ Effects 연결)
if loaded.WorldService and loaded.Effects then
	loaded.WorldService.onFall = function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			loaded.Effects.sound3d(root.Position, "Splash")
		end
		loaded.Effects.toPlayer(player, "fell", {})
	end
end

print("[졸졸 동물 기차] 준비 완료")
