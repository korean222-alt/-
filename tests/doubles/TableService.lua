-- 테스트용 TableService 대역. 진짜와 같은 이름의 API 만 갖춘다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = require(ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared"):WaitForChild("Utility"))

local TableService = {}
TableService._tables = {}
TableService.TableAdded = Utility.Signal.new()
TableService.TableRemoved = Utility.Signal.new()

function TableService:Register(gameTable)
	table.insert(self._tables, gameTable)
	self.TableAdded:Fire(gameTable)
end

function TableService:GetTableOfPlayer(player)
	for _, gameTable in ipairs(self._tables) do
		if gameTable:HasPlayer(player) then
			return gameTable
		end
	end
	return nil
end

function TableService:GetTableFromModel(model)
	for _, gameTable in ipairs(self._tables) do
		if gameTable.model == model then
			return gameTable
		end
	end
	return nil
end

function TableService:GetAllTables()
	return table.clone(self._tables)
end

return TableService
