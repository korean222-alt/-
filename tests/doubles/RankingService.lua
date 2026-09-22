-- 테스트용 RankingService 대역. 호출만 기록한다.
local RankingService = { calls = {} }

function RankingService:RecordRound(gameTable, roster, winner)
	table.insert(self.calls, { tableId = gameTable and gameTable.tableId, roster = #(roster or {}), winner = winner and winner.Name })
end

function RankingService:Refresh() end

return RankingService
