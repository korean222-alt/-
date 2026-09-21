--[[
	TableConfig
	테이블 "종류"별 규칙 정의.

	테이블 모델에 TableType Attribute 로 아래 키 중 하나를 적어두면
	그 테이블은 해당 규칙으로 동작한다.
	새 테이블 종류(6인, VIP, 특수 룰)를 추가할 때 이 표에 한 줄만 더하면 된다.
]]

local TableConfig = {}

TableConfig.Types = {
	-- Phase 1 의 기본 테이블
	Standard4 = {
		DisplayName = "4인 테이블",
		SeatCount = 4, -- 모델에 실제로 있는 좌석 수와 다르면 실제 좌석 수가 우선한다
		MinPlayers = 2, -- 이 인원이 모이면 카운트다운 시작
		KnifeSlots = 16, -- Phase 3 에서 사용
		DangerSlots = 1, -- Phase 3 에서 사용
		TurnDuration = 7, -- 한 턴 제한 시간(초)
		CountdownDuration = 10, -- 게임 시작 카운트다운(초)
	},

	-- 다음 단계에서 쓸 2인 테이블 (지금 만들어 둬도 코드가 그대로 돌아간다)
	Duo2 = {
		DisplayName = "2인 테이블",
		SeatCount = 2,
		MinPlayers = 2,
		KnifeSlots = 10,
		DangerSlots = 1,
		TurnDuration = 7,
		CountdownDuration = 8,
	},
}

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

return TableConfig
