--[[
	TableService
	Workspace 에 있는 모든 게임 테이블을 찾아 GameTable 객체로 만들어 관리한다.

	CollectionService 태그 기반이라
	테이블 모델을 복제해서 Workspace 에 놓고 태그만 붙이면 자동으로 등록된다.
	(Table01, Table02 같은 이름 하드코딩 없음)

	Phase 2 추가
	  - TableAdded / TableRemoved 신호. RoundService 가 이 신호를 듣고
	    테이블마다 라운드 진행 담당자를 하나씩 붙였다 떼었다 한다.

	Phase 3 에서는 달라진 것이 없다.
	테이블이 등록될 때 GameTable 이 통 둘레의 칼 슬롯까지 갖추기 때문에,
	여기서는 여전히 "찾아서 등록하고 알린다"만 하면 된다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local GameTable = require(script.Parent.GameTable)

local TABLE_TAG = GameConfig.Tags.Table

local TableService = {}
TableService._tables = {} -- [Model] = GameTable
TableService._cleaner = Utility.Cleaner.new()
TableService._started = false

-- 테이블이 등록/해제될 때 알린다. (gameTable) 하나를 전달한다.
TableService.TableAdded = Utility.Signal.new()
TableService.TableRemoved = Utility.Signal.new()

--------------------------------------------------
-- 등록 / 해제
--------------------------------------------------

function TableService:_register(model)
	if self._tables[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
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

	if self:GetTableById(gameTable.tableId) then
		gameTable.tableId = gameTable.tableId .. "_" .. game:GetService("HttpService"):GenerateGUID(false)
		model:SetAttribute(GameConfig.TableAttributes.TableId, gameTable.tableId)
	end
	self._tables[model] = gameTable
	gameTable.cleaner:add(model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then self:_unregister(model) end
	end))
	GameConfig.log(("테이블 등록: %s (%s, 좌석 %d개)"):format(gameTable.tableId, gameTable.typeName, #gameTable.seats))

	self.TableAdded:Fire(gameTable)
end

function TableService:_unregister(model)
	local gameTable = self._tables[model]
	if not gameTable then
		return
	end

	self._tables[model] = nil

	-- 정리를 시작하기 전에 알린다.
	-- RoundService 가 먼저 손을 떼야, 철거 과정에서 사람들이 일어나는 것을
	-- "라운드 도중 이탈"로 착각하지 않는다.
	self.TableRemoved:Fire(gameTable)

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

	self._cleaner:add(workspace.DescendantAdded:Connect(function(model)
		if model:IsA("Model") and CollectionService:HasTag(model, TABLE_TAG) then self:_register(model) end
	end))
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
