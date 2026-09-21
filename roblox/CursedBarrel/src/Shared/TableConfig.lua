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
		MinPlayers = 1, -- ★ 이 인원이 모이면 카운트다운 시작 / 이 아래로 떨어지면 즉시 취소
		KnifeSlots = 16, -- Phase 3 에서 사용
		DangerSlots = 1, -- Phase 3 에서 사용
		TurnDuration = 7, -- 한 턴 제한 시간(초)
		CountdownDuration = 5, -- 게임 시작 카운트다운(초)
		AutoAdvanceTurn = true, -- 제한 시간이 끝나면 다음 사람에게 턴을 넘긴다
	},

	-- 2인 테이블
	Duo2 = {
		DisplayName = "2인 테이블",
		SeatCount = 2,
		MinPlayers = 1, -- ★ 위와 같은 규칙
		KnifeSlots = 10,
		DangerSlots = 1,
		TurnDuration = 7,
		CountdownDuration = 5,
		AutoAdvanceTurn = true,
	},
}

--[[
	★ MinPlayers 안내 (혼자 테스트 vs 실제 출시)

	MinPlayers 는 "카운트다운을 시작하는 인원"이자 "이 아래로 떨어지면 취소하는 인원"이다.
	지금은 1 로 두었기 때문에

	  - 혼자 앉아도 5초 카운트다운이 시작되고
	  - 그 사람이 일어나면(=0명) 카운트다운이 즉시 취소된다.

	실제 출시처럼 "2명 미만이면 취소"로 만들고 싶으면 위 표의 MinPlayers 를 2 로 바꾸면 된다.
	그 한 곳만 바꾸면 서버 판정, 현황판 문구, 라운드 정리까지 전부 따라온다.
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

return TableConfig
