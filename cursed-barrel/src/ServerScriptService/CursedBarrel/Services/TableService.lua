--[[
	TableService
	Workspace 에 있는 모든 게임 테이블을 찾아 GameTable 객체로 만들어 관리한다.

	CollectionService 태그 기반이라
	테이블 모델을 복제해서 Workspace 에 놓고 태그만 붙이면 자동으로 등록된다.
	(Table01, Table02 같은 이름 하드코딩 없음)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Utility = require(Shared.Utility)

local GameTable = require(script.Parent.GameTable)

local TABLE_TAG = GameConfig.Tags.Table

local TableService = {}
TableService._tables = {} -- [Model] = GameTable
TableService._cleaner = Utility.Cleaner.new()
TableService._started = false

--------------------------------------------------
-- 등록 / 해제
--------------------------------------------------

function TableService:_register(model)
	if self._tables[model] then
		return
	end

	local ok, result = pcall(GameTable.new, model)
	if not ok then
		warn(("[CursedBarrel] 테이블 생성 실패 (%s): %s"):format(model:GetFullName(), tostring(result)))
		return
	end

	local gameTable = result
	if not gameTable then
		return -- 구조 문제. GameTable.new 가 이미 경고를 남겼다.
	end

	self._tables[model] = gameTable
	GameConfig.log(("테이블 등록: %s (%s, 좌석 %d개)"):format(gameTable.tableId, gameTable.typeName, #gameTable.seats))
end

function TableService:_unregister(model)
	local gameTable = self._tables[model]
	if not gameTable then
		return
	end

	self._tables[model] = nil

	local ok, err = pcall(function()
		gameTable:Destroy()
	end)
	if not ok then
		warn("[CursedBarrel] 테이블 정리 중 오류: " .. tostring(err))
	end

	GameConfig.log("테이블 해제: " .. tostring(gameTable.tableId))
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function TableService:Start()
	if self._started then
		return
	end
	self._started = true

	-- 이미 배치되어 있는 테이블들
	for _, model in ipairs(CollectionService:GetTagged(TABLE_TAG)) do
		self:_register(model)
	end

	-- 게임 도중에 추가/삭제되는 테이블들
	self._cleaner:add(CollectionService:GetInstanceAddedSignal(TABLE_TAG):Connect(function(model)
		self:_register(model)
	end))

	self._cleaner:add(CollectionService:GetInstanceRemovedSignal(TABLE_TAG):Connect(function(model)
		self:_unregister(model)
	end))

	-- 플레이어가 나가면 어느 테이블에 앉아 있었든 정리한다.
	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		for _, gameTable in pairs(self._tables) do
			gameTable:HandlePlayerRemoving(player)
		end
	end))

	local count = 0
	for _ in pairs(self._tables) do
		count += 1
	end
	GameConfig.log(("TableService 시작 완료 · 테이블 %d개"):format(count))
end

--------------------------------------------------
-- 조회 API
--------------------------------------------------

function TableService:GetTableOfPlayer(player)
	for _, gameTable in pairs(self._tables) do
		if gameTable:HasPlayer(player) then
			return gameTable
		end
	end
	return nil
end

function TableService:GetTableById(tableId)
	for _, gameTable in pairs(self._tables) do
		if gameTable.tableId == tableId then
			return gameTable
		end
	end
	return nil
end

function TableService:GetTableFromModel(model)
	return self._tables[model]
end

function TableService:GetAllTables()
	local list = {}
	for _, gameTable in pairs(self._tables) do
		table.insert(list, gameTable)
	end
	return list
end

return TableService
