--[[
	Main
	서버 진입점. 서비스들을 순서대로 켜는 일만 한다.

	위치: ServerScriptService > CursedBarrel > Main  (Script)

	순서에 이유가 있다.
	  1. ProfileService  — 나머지가 코인과 스킨을 물어보므로 가장 먼저
	  2. PurchaseService — 영수증 처리의 유일한 주인. 상품 등록보다 먼저 켜 둔다
	  3. TableService    — 테이블 등록 (좌석 · 칼 슬롯 · 프롬프트가 이때 갖춰진다)
	  4. RankingService  — 랭킹판
	  5. RoundService    — 테이블마다 라운드 담당자
	  6. ShopService     — 상점 (로벅스 상품을 PurchaseService 에 등록한다)
	  7. SabotageService — 방해 아이템 (RoundService 가 있어야 한다)
	  8. LobbyBuilder    — 간판 · 전시장 (ShopService 를 쓴다)
	  9. MapBuilder      — 항구와 해적선. 무거운 장식이라 마지막에 세운다
	 10. BotService      — Phase 11 AI 선원. 테이블과 라운드 담당이 다 선 뒤에 켠다
	 11. WorldService    — Phase 12 항해 시계 · 크라켄 습격 · 행운의 테이블
	 12. CannonService   — Phase 12 대포 미니게임 (배가 선 뒤에 대포를 찾는다)
	 13. PredictionService · TournamentService — Phase 12 관전 예측 · 토너먼트
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("CursedBarrel"):WaitForChild("Services")

local ProfileService = require(Services.ProfileService)
local PurchaseService = require(Services.PurchaseService)
local TableService = require(Services.TableService)
local RankingService = require(Services.RankingService)
local RoundService = require(Services.RoundService)
local ShopService = require(Services.ShopService)
local SabotageService = require(Services.SabotageService)
local LobbyBuilder = require(Services.LobbyBuilder)
local MapBuilder = require(Services.MapBuilder)
local BotService = require(Services.BotService)
local WorldService = require(Services.WorldService)
local CannonService = require(Services.CannonService)
local PredictionService = require(Services.PredictionService)
local TournamentService = require(Services.TournamentService)
local RewardService = require(Services.RewardService)

-- Relocate whole table models before GameTable caches seat/slot geometry.
require(Services.ShipLobbyBuilder):Prepare()
ProfileService:Start()
PurchaseService:Start()
TableService:Start()
RankingService:Start()
RoundService:Start()
ShopService:Start()
SabotageService:Start()
LobbyBuilder:Start()
require(Services.ReleaseService):Start()
BotService:Start()
WorldService:Start()
CannonService:Start()
PredictionService:Start()
TournamentService:Start()
RewardService:Start()

-- 항구는 파트가 많다. 첫 프레임이 지난 뒤에 세워야 접속이 늦어지지 않는다.
task.defer(function()
	MapBuilder:Start()
end)

print("[CursedBarrel] 서버 부팅 완료 (Phase 13: 출석판 · 룰렛 · 코인/로벅스 스킨 · 영어)")
