--[[
	Main
	서버 진입점. 서비스들을 순서대로 켜는 일만 한다.

	위치: ServerScriptService > CursedBarrel > Main  (Script)
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("CursedBarrel"):WaitForChild("Services")
local TableService = require(Services.TableService)
local RankingService = require(Services.RankingService)
local RoundService = require(Services.RoundService)

-- 1) 테이블을 찾아 등록한다. (좌석 · 칼 슬롯 · 프롬프트가 이때 갖춰진다)
-- 2) 랭킹판을 찾아 비워 둔 판을 그린다.
-- 3) 라운드 담당자를 테이블마다 붙인다.
-- (순서가 바뀌어도 RoundService 가 기존 테이블을 훑기 때문에 문제는 없다)
TableService:Start()
RankingService:Start()
RoundService:Start()

print("[CursedBarrel] 서버 부팅 완료 (Phase 3: 칼 슬롯 · 위험 자리 · 탈락 · 마지막 생존자 승리)")
