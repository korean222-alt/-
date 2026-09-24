--[[
	TableConfig
	테이블 "종류"별 규칙 정의.

	테이블 모델에 TableType Attribute 로 아래 키 중 하나를 적어두면
	그 테이블은 해당 규칙으로 동작한다.

	Phase 8 에서 늘어난 것
	  - Party6 : 6인 테이블. 좌석이 많은 만큼 통에 해적을 두 마리 숨긴다.
	  - Blitz4 : 빠른 모드. 턴이 짧고 통이 작아 한 판이 금방 끝난다.
	  - 좌석 수만 보고도 해적 수를 정할 수 있는 dangerForSeats
]]

local TableConfig = {}

TableConfig.Types = {
	-- Phase 1 의 기본 테이블
	Standard4 = {
		DisplayName = "4인 테이블",
		SeatCount = 4, -- 모델에 실제로 있는 좌석 수와 다르면 실제 좌석 수가 우선한다
		MinPlayers = 2, -- ★ 이 인원이 모이면 카운트다운 시작 / 이 아래로 떨어지면 즉시 취소
		KnifeSlots = 16, -- 통 둘레의 칼 슬롯 개수
		DangerSlots = 1, -- 그중 몇 개가 "터지는" 자리인지 (라운드마다 서버가 새로 뽑는다)
		TurnDuration = 7,
		CountdownDuration = 5,
		AutoAdvanceTurn = true,
		AutoPickOnTimeout = true,
		RefillOnElimination = true, -- 누가 탈락하면 통을 새 칼로 다시 채운다
		RewardScale = 1,
	},

	-- 2인 테이블
	Duo2 = {
		DisplayName = "2인 테이블",
		SeatCount = 2,
		MinPlayers = 2,
		KnifeSlots = 10,
		DangerSlots = 1,
		TurnDuration = 7,
		CountdownDuration = 5,
		AutoAdvanceTurn = true,
		AutoPickOnTimeout = true,
		RefillOnElimination = true,
		RewardScale = 0.7,
	},

	-- Phase 8 : 6인 테이블
	-- 사람이 많으면 한 바퀴가 길어서 한 마리로는 긴장이 끊긴다. 그래서 두 마리를 숨긴다.
	Party6 = {
		DisplayName = "6인 테이블",
		SeatCount = 6,
		MinPlayers = 2,
		KnifeSlots = 24,
		DangerSlots = 2, -- ★ 해적 두 마리
		TurnDuration = 7,
		CountdownDuration = 6,
		AutoAdvanceTurn = true,
		AutoPickOnTimeout = true,
		RefillOnElimination = true,
		RewardScale = 1.25,
	},

	-- Phase 8 : 빠른 모드
	Blitz4 = {
		DisplayName = "빠른 테이블",
		SeatCount = 4,
		MinPlayers = 2,
		KnifeSlots = 10,
		DangerSlots = 1,
		TurnDuration = 4,
		CountdownDuration = 4,
		AutoAdvanceTurn = true,
		AutoPickOnTimeout = true,
		RefillOnElimination = true,
		RewardScale = 0.85,
	},
}

--[[
	★ MinPlayers 안내 (혼자 테스트 vs 실제 출시)

	MinPlayers 는 "카운트다운을 시작하는 인원"이자 "이 아래로 떨어지면 취소하는 인원"이다.
	지금은 1 로 두었기 때문에 혼자 앉아도 5초 뒤에 시작된다.
	실제 출시처럼 "2명 미만이면 취소"로 만들고 싶으면 위 표의 MinPlayers 를 2 로 바꾸면 된다.
]]

TableConfig.DefaultType = "Standard4"

-- 알 수 없는 종류가 들어와도 게임이 멈추지 않도록 기본값으로 되돌린다.
function TableConfig.get(typeName)
	local preset = TableConfig.Types[typeName]
	if not preset then
		if typeName ~= nil then
			warn(("[CursedBarrel] 알 수 없는 TableType '%s' → 기본값 '%s' 사용"):format(tostring(typeName), TableConfig.DefaultType))
		end
		preset = TableConfig.Types[TableConfig.DefaultType]
	end
	return preset
end

-- 슬롯 개수는 최소 2개는 되어야 게임이 성립한다.
function TableConfig.getSlotCount(typeName)
	local preset = TableConfig.get(typeName)
	return math.max(2, math.floor(tonumber(preset.KnifeSlots) or 16))
end

-- 좌석 수만으로 정하는 해적 수.
-- 좌석 3개마다 한 마리. 2·4인은 한 마리, 6인은 두 마리가 된다.
function TableConfig.dangerForSeats(seatCount)
	local seats = math.max(1, math.floor(tonumber(seatCount) or 1))
	return math.max(1, math.floor(seats / 3))
end

-- 위험 자리 수는 1개 이상, 슬롯 수보다는 적어야 한다. (전부 위험이면 게임이 안 된다)
-- 실제 좌석 수를 넘기면 그쪽이 우선한다. 모델에 의자를 더 붙여도 자동으로 맞는다.
function TableConfig.getDangerCount(typeName, seatCount)
	local preset = TableConfig.get(typeName)
	local slots = TableConfig.getSlotCount(typeName)
	local danger = math.floor(tonumber(preset.DangerSlots) or 1)
	if seatCount then
		danger = math.max(danger, TableConfig.dangerForSeats(seatCount))
	end
	return math.clamp(danger, 1, math.max(1, slots - 1))
end

function TableConfig.getRewardScale(typeName)
	return tonumber(TableConfig.get(typeName).RewardScale) or 1
end

-- Phase 15 : 4인 이상 테이블은 "최후의 1인이 전부 가져간다".
--   판 도중에 버는 코인(안전한 자리 · 잡기 · 배짱)은 바로 주지 않고 현상금에 쌓인다. 한 명씩 탈락해 올라가고,
--   마지막까지 살아남은 한 명이 쌓인 현상금과 우승 보상을 전부 받는다. 탈락한 사람은 코인을 받지 않는다.
--   (퀘스트 · 업적 진행은 그대로 쌓인다.) 2인 테이블은 예전 그대로다.
for _, key in ipairs({ "Standard4", "Party6", "Blitz4" }) do
	TableConfig.Types[key].WinnerTakesAll = true
end

TableConfig.Types.PartyCards6 = table.clone(TableConfig.Types.Party6)
TableConfig.Types.PartyCards6.DisplayName = "파티 카드 · 6인"
TableConfig.Types.PartyCards6.SpecialCards = true
-- Phase 12 : 토너먼트 테이블. 4판 연속 점수로 시즌 순위를 겨룬다. AI 선원은 앉지 않는다.
TableConfig.Types.Tournament4 = table.clone(TableConfig.Types.Standard4)
TableConfig.Types.Tournament4.DisplayName = "토너먼트 테이블"
TableConfig.Types.Tournament4.Tournament = true
TableConfig.Types.Tournament4.NoBots = true
if game:GetService("RunService"):IsStudio() and require(script.Parent.ReleaseConfig).StudioSolo then
 for _, preset in pairs(TableConfig.Types) do preset.MinPlayers = 1 end
end
return TableConfig
