-- 테스트용 ProfileService 대역. 코인과 통계만 세어 둔다.
local ProfileService = { awards = {}, streakBreaks = {}, rounds = {} }

function ProfileService:Award(player, coins, metric)
	local name = player and player.Name or "?"
	self.awards[name] = self.awards[name] or { coins = 0, metrics = {} }
	self.awards[name].coins += math.floor(tonumber(coins) or 0)
	if metric then
		self.awards[name].metrics[metric] = (self.awards[name].metrics[metric] or 0) + 1
	end
end

function ProfileService:BreakStreak(player)
	local name = player and player.Name or "?"
	self.streakBreaks[name] = (self.streakBreaks[name] or 0) + 1
end

function ProfileService:RecordRound(gameTable, roster, winner)
	table.insert(self.rounds, { roster = #(roster or {}), winner = winner and winner.Name })
end

function ProfileService:Get()
	return nil
end

return ProfileService
