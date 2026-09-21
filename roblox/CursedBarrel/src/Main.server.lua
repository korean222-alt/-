--[[
	Main
	서버 진입점. 서비스들을 순서대로 켜는 일만 한다.

	위치: ServerScriptService > CursedBarrel > Main  (Script)
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("CursedBarrel"):WaitForChild("Services")
local TableService = require(Services.TableService)
local RoundService = require(Services.RoundService)

-- 테이블을 먼저 찾아 등록하고, 그 다음 라운드 담당자를 붙인다.
-- (순서가 바뀌어도 RoundService 가 기존 테이블을 훑기 때문에 문제는 없다)
TableService:Start()
RoundService:Start()

print("[CursedBarrel] 서버 부팅 완료 (Phase 2: 카운트다운 · 라운드 시작 · 턴 순서)")
