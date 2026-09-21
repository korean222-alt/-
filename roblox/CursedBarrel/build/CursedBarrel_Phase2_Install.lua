-- 저주받은 통 · Phase 2 업데이트 설치
-- Play/Run을 멈춘 Studio 편집 모드의 Command Bar에 전체 내용을 한 번 붙여넣으세요.
-- 외부 다운로드, HTTP 허용, LoadStringEnabled, 플러그인이 필요하지 않습니다.
-- 같은 이름의 스크립트만 교체하고 기존 항목은 ServerStorage에 백업합니다.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "[CursedBarrel] Play/Run을 먼저 멈추고 Command Bar에서 실행하세요.")

--------------------------------------------------
-- 설치 옵션
--------------------------------------------------
local APPLY_LIGHTING = true -- 로비를 밝은 조명으로 바꾼다 (게임 시작 시 어두워지는 연출은 클라이언트가 담당)
local REBUILD_MAP = true -- 로비 맵 + 테이블 6개를 새로 만든다. false 면 스크립트만 갱신한다.
local REPLACE_SPAWN = true -- 기존 SpawnLocation 을 백업하고 로비 스폰을 사용한다
local LOBBY_ORIGIN = Vector3.new(0, 1, 0) -- 로비 바닥 윗면의 높이/위치

-- 한 게임방에 놓을 테이블 목록. 줄을 더하거나 지우면 그대로 반영된다.
local TABLE_LAYOUT = {
	{ name = "Table_A", tableType = "Standard4", seatCount = 4, offset = Vector3.new(-44, 0, -20) },
	{ name = "Table_B", tableType = "Standard4", seatCount = 4, offset = Vector3.new(0, 0, -20) },
	{ name = "Table_C", tableType = "Standard4", seatCount = 4, offset = Vector3.new(44, 0, -20) },
	{ name = "Table_D", tableType = "Standard4", seatCount = 4, offset = Vector3.new(-44, 0, 18) },
	{ name = "Table_E", tableType = "Duo2", seatCount = 2, offset = Vector3.new(0, 0, 18) },
	{ name = "Table_F", tableType = "Duo2", seatCount = 2, offset = Vector3.new(44, 0, 18) },
}

local SOURCES = {}
SOURCES.GameConfig = [====[
--[[
	GameConfig
	게임 전역에서 공유하는 설정값과 이름 상수 모음.

	문자열을 직접 여기저기 적지 않고 전부 이 파일을 거치게 한다.
	나중에 이름을 바꿔야 할 때 한 곳만 고치면 되고, 오타로 인한 버그도 막아준다.

	Phase 2 에서 늘어난 것
	  - 카운트다운 / 라운드 / 턴 Attribute 이름
	  - 로비(밝음) · 게임 중(어두움) 라이팅 프리셋
]]

local GameConfig = {}

-- 개발 중에는 true. 출시 전에 false 로 바꾸면 로그가 조용해진다.
GameConfig.DEBUG = true

--------------------------------------------------
-- CollectionService 태그
-- Workspace 에 테이블 모델을 복제하고 이 태그만 붙이면 자동으로 게임에 등록된다.
--------------------------------------------------
GameConfig.Tags = {
	Table = "CursedBarrel_Table",
	Seat = "CursedBarrel_Seat",
}

--------------------------------------------------
-- 테이블 모델에 서버가 기록하는 Attribute 이름
-- 클라이언트는 이 Attribute 만 읽어서 UI 를 그린다. (RemoteEvent 가 필요 없다)
--------------------------------------------------
GameConfig.TableAttributes = {
	-- Phase 1
	TableId = "TableId", -- 테이블 고유 ID (문자열)
	TableType = "TableType", -- TableConfig.Types 의 키
	SeatCount = "SeatCount", -- 총 좌석 수
	SeatedCount = "SeatedCount", -- 현재 앉아 있는 인원
	MinPlayers = "MinPlayers", -- 시작에 필요한 최소 인원
	State = "State", -- 현재 상태 머신 상태

	-- Phase 2 : 카운트다운
	-- 남은 초를 매 틱 기록하지 않고 "끝나는 시각" 하나만 기록한다.
	-- 클라이언트가 workspace:GetServerTimeNow() 로 빼서 쓰면 네트워크 부담 없이 부드럽다.
	CountdownEndsAt = "CountdownEndsAt", -- 서버 시계 기준 종료 시각 (0 = 카운트다운 없음)
	CountdownDuration = "CountdownDuration", -- 이번 카운트다운의 전체 길이(초)

	-- Phase 2 : 라운드 / 턴
	RoundId = "RoundId", -- 이 테이블에서 몇 번째 라운드인지
	ParticipantCount = "ParticipantCount", -- 확정된 참가자 수
	TurnCount = "TurnCount", -- 턴 순서에 남아 있는 인원
	TurnIndex = "TurnIndex", -- 현재 몇 번째 차례인지 (1 부터)
	CurrentTurnUserId = "CurrentTurnUserId", -- 현재 차례인 플레이어 UserId (0 = 없음)
	CurrentTurnName = "CurrentTurnName", -- 현재 차례인 플레이어 표시 이름
	TurnEndsAt = "TurnEndsAt", -- 이번 턴 제한시간 종료 시각 (0 = 제한 없음)
}

--------------------------------------------------
-- 좌석(Seat)에 기록하는 Attribute 이름
--------------------------------------------------
GameConfig.SeatAttributes = {
	SeatIndex = "SeatIndex", -- 1 부터 시작하는 좌석 번호
	OccupantUserId = "OccupantUserId", -- 앉아 있는 플레이어 UserId (비었으면 0)
	TurnOrder = "TurnOrder", -- Phase 2: 이번 라운드의 턴 순서 (0 = 참가자 아님)
}

--------------------------------------------------
-- 테이블 상태 머신
-- Phase 2 에서는 Waiting / Countdown / Playing 을 사용한다.
-- Starting / RoundEnding 은 Phase 3 의 연출용으로 비워둔다.
--------------------------------------------------
GameConfig.States = {
	Waiting = "Waiting", -- 사람을 기다리는 중
	Countdown = "Countdown", -- 최소 인원이 모여 카운트다운 중
	Starting = "Starting", -- 시작 연출 중
	Playing = "Playing", -- 라운드 진행 중
	RoundEnding = "RoundEnding", -- 승자 연출 중
	Resetting = "Resetting", -- 테이블 초기화 중
}

-- 게임에 새로 참가할 수 있는 상태들
-- Playing 이 여기에 없기 때문에 게임이 시작되면 빈 의자에도 앉을 수 없다.
GameConfig.JoinableStates = {
	[GameConfig.States.Waiting] = true,
	[GameConfig.States.Countdown] = true,
}

-- "게임이 진행 중"으로 취급하는 상태들. 이 동안 내 화면 조명이 어두워진다.
GameConfig.InGameStates = {
	[GameConfig.States.Starting] = true,
	[GameConfig.States.Playing] = true,
	[GameConfig.States.RoundEnding] = true,
}

--------------------------------------------------
-- 좌석 ProximityPrompt 설정
-- PC(E 키)와 모바일(탭) 모두 기본 지원되기 때문에 ClickDetector 대신 사용한다.
--------------------------------------------------
GameConfig.SeatPrompt = {
	ActionText = "앉기",
	HoldDuration = 0,
	MaxActivationDistance = 12,
	RequiresLineOfSight = false,
}

-- 같은 플레이어가 Prompt 를 연타해도 이 간격 안에서는 한 번만 처리한다.
GameConfig.PromptCooldown = 0.35

--------------------------------------------------
-- 서버와 클라이언트가 같은 시계를 본다.
-- 카운트다운 / 턴 남은 시간 계산은 전부 이 값을 기준으로 한다.
--------------------------------------------------
function GameConfig.now()
	return workspace:GetServerTimeNow()
end

--------------------------------------------------
-- 라이팅 프리셋 (Phase 2)
--
-- 로비는 스킨 전시장이라 밝아야 하고, 게임이 시작되면 어두워진다.
-- 조명 변경은 LightingController(클라이언트)가 "내 화면에서만" 수행하므로
-- 옆 테이블에서 게임이 시작돼도 로비에 있는 사람의 화면은 밝은 그대로다.
--------------------------------------------------
GameConfig.Lighting = {
	-- 접속하자마자 로비 프리셋을 한 번 적용할지 여부
	ApplyLobbyOnJoin = true,
	TweenTime = 1.4, -- 밝음 <-> 어두움 전환에 걸리는 시간(초)

	Lobby = {
		Ambient = Color3.fromRGB(122, 120, 116),
		OutdoorAmbient = Color3.fromRGB(154, 158, 168),
		Brightness = 2.8,
		ClockTime = 14.3,
		ExposureCompensation = 0,
		FogColor = Color3.fromRGB(206, 214, 224),
		FogEnd = 100000,
		Atmosphere = {
			Density = 0.26,
			Offset = 0.1,
			Color = Color3.fromRGB(226, 226, 220),
			Decay = Color3.fromRGB(150, 165, 185),
			Glare = 0,
			Haze = 0.6,
		},
		Bloom = { Intensity = 0.3, Size = 22, Threshold = 1.3 },
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.06,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 252, 246),
		},
	},

	Game = {
		Ambient = Color3.fromRGB(38, 32, 28),
		OutdoorAmbient = Color3.fromRGB(28, 34, 44),
		Brightness = 1.2,
		ClockTime = 21.4,
		ExposureCompensation = 0.2,
		FogColor = Color3.fromRGB(28, 26, 30),
		FogEnd = 100000,
		Atmosphere = {
			Density = 0.42,
			Offset = 0.2,
			Color = Color3.fromRGB(190, 176, 158),
			Decay = Color3.fromRGB(58, 62, 78),
			Glare = 0.3,
			Haze = 2.2,
		},
		Bloom = { Intensity = 0.75, Size = 28, Threshold = 0.95 },
		ColorCorrection = {
			Brightness = -0.02,
			Contrast = 0.16,
			Saturation = -0.05,
			TintColor = Color3.fromRGB(255, 240, 224),
		},
	},
}

--------------------------------------------------
-- 디버그 로그
--------------------------------------------------
function GameConfig.log(...)
	if GameConfig.DEBUG then
		print("[CursedBarrel]", ...)
	end
end

return GameConfig
]====]
SOURCES.TableConfig = [====[
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
]====]
SOURCES.Utility = [====[
--[[
	Utility
	서버/클라이언트가 함께 쓰는 작은 도구 모음.

	- Cleaner     : 연결(Connection)/인스턴스/Tween 을 한 번에 정리
	- Signal      : 가벼운 자체 이벤트 (BindableEvent 과 달리 값이 복사되지 않는다)
	- RateLimiter : 요청 스팸 방지
]]

local Utility = {}

--------------------------------------------------
-- Cleaner
-- 라운드가 끝나거나 테이블이 사라질 때 남은 찌꺼기를 전부 치우는 역할.
--------------------------------------------------
local Cleaner = {}
Cleaner.__index = Cleaner

function Cleaner.new()
	return setmetatable({ _items = {} }, Cleaner)
end

-- 정리 대상 등록. 등록한 값을 그대로 돌려주므로 한 줄로 쓸 수 있다.
--   local conn = cleaner:add(part.Touched:Connect(fn))
function Cleaner:add(item)
	table.insert(self._items, item)
	return item
end

function Cleaner:clean()
	-- 나중에 등록된 것부터 역순으로 정리한다.
	for index = #self._items, 1, -1 do
		local item = self._items[index]
		self._items[index] = nil

		local ok, err = pcall(function()
			local kind = typeof(item)
			if kind == "RBXScriptConnection" then
				item:Disconnect()
			elseif kind == "Instance" then
				item:Destroy()
			elseif kind == "function" then
				item()
			elseif kind == "table" then
				if typeof(item.Destroy) == "function" then
					item:Destroy()
				elseif typeof(item.Disconnect) == "function" then
					item:Disconnect()
				end
			end
		end)

		if not ok then
			warn("[CursedBarrel] Cleaner 정리 중 오류: " .. tostring(err))
		end
	end
end

Cleaner.Destroy = Cleaner.clean
Utility.Cleaner = Cleaner

--------------------------------------------------
-- Signal
-- 테이블 인원 변화 같은 내부 알림용. 여러 곳에서 구독할 수 있다.
--------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(handler)
	assert(typeof(handler) == "function", "Signal:Connect 에는 함수가 필요합니다")

	local connection = {
		Connected = true,
		_handler = handler,
		_signal = self,
	}

	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local list = self._signal._connections
		local index = table.find(list, self)
		if index then
			table.remove(list, index)
		end
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	-- 처리 도중 Disconnect 가 일어나도 안전하도록 복사본을 순회한다.
	local snapshot = table.clone(self._connections)
	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:Destroy()
	for _, connection in ipairs(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

Utility.Signal = Signal

--------------------------------------------------
-- RateLimiter
-- 같은 키(보통 UserId)로 들어오는 요청을 일정 간격으로 제한한다.
--------------------------------------------------
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(interval)
	return setmetatable({
		_interval = interval or 0.5,
		_lastAt = {},
	}, RateLimiter)
end

-- 통과하면 true, 너무 빠르면 false
function RateLimiter:check(key)
	local now = os.clock()
	local last = self._lastAt[key]
	if last and (now - last) < self._interval then
		return false
	end
	self._lastAt[key] = now
	return true
end

-- 플레이어가 나가면 기록을 지워 메모리가 쌓이지 않게 한다.
function RateLimiter:forget(key)
	self._lastAt[key] = nil
end

Utility.RateLimiter = RateLimiter

--------------------------------------------------
-- 공용 헬퍼
--------------------------------------------------

-- 살아있는 Humanoid 를 돌려준다. 캐릭터가 없거나 죽었으면 nil.
function Utility.getHumanoid(player)
	local character = player and player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

-- 배열에서 값 하나를 제거한다. 제거했으면 true.
function Utility.removeValue(array, value)
	local index = table.find(array, value)
	if index then
		table.remove(array, index)
		return true
	end
	return false
end

-- 배열을 제자리에서 섞는다. (Fisher-Yates)
-- random 에 Random 객체를 넘기면 서버 전용 난수를 쓸 수 있다. (Phase 2 턴 순서 결정용)
function Utility.shuffle(array, random)
	for index = #array, 2, -1 do
		local pick
		if random then
			pick = random:NextInteger(1, index)
		else
			pick = math.random(1, index)
		end
		array[index], array[pick] = array[pick], array[index]
	end
	return array
end

-- 남은 시간 표시용. 10초 미만이면 소수점 한 자리까지 보여준다.
function Utility.formatSeconds(seconds)
	if seconds < 0 then
		seconds = 0
	end
	if seconds >= 10 then
		return ("%d초"):format(math.floor(seconds + 0.5))
	end
	return ("%.1f초"):format(seconds)
end

return Utility
]====]
SOURCES.GameTable = [====[
--[[
	GameTable
	게임 테이블 하나를 담당하는 서버 측 객체.

	Phase 1 담당 범위
	  - 모델 안의 Seat 을 찾아 좌석 목록을 만든다
	  - 좌석마다 "앉기" ProximityPrompt 를 붙인다
	  - 누가 앉고 일어나는지 서버가 직접 감시해 참가자 명단을 관리한다
	  - 현재 인원을 테이블 Attribute 로 기록한다 (클라이언트 UI 가 이걸 읽는다)

	Phase 2 에서 더해진 것
	  - 카운트다운/턴 Attribute 자리를 미리 만들어 둔다 (값은 RoundService 가 채운다)
	  - GetSeats / GetPlayerOfSeat / GetMinPlayers / SetTableAttribute 같은 조회용 API
	  - 게임이 시작되면 "빈 좌석"만 잠근다 (앉아 있는 참가자는 건드리지 않는다)

	테이블마다 독립된 객체이므로 한 테이블의 일이 다른 테이블에 영향을 주지 않는다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes

local GameTable = {}
GameTable.__index = GameTable

-- TableId Attribute 가 없는 모델에 붙여줄 자동 번호
local autoIdCounter = 0
local playerTables = {} -- 한 플레이어는 한 테이블의 한 좌석만 소유

--------------------------------------------------
-- 생성 / 파괴
--------------------------------------------------

-- 구조가 잘못된 모델이면 경고만 남기고 nil 을 돌려준다. (게임 전체가 멈추지 않게)
function GameTable.new(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[CursedBarrel] 테이블 태그는 Model 에만 붙일 수 있습니다: " .. tostring(model))
		return nil
	end

	-- 런타임에 복제된 테이블은 자식이 아직 도착하지 않았을 수 있다.
	local seatsFolder = model:FindFirstChild("Seats")
	if not seatsFolder then
		warn(("[CursedBarrel] '%s' 안에 Seats 폴더가 없어 등록하지 못했습니다."):format(model:GetFullName()))
		return nil
	end

	autoIdCounter += 1

	local self = setmetatable({}, GameTable)

	self.model = model
	self.tableId = model:GetAttribute(TABLE_ATTR.TableId) or ("Table_%02d"):format(autoIdCounter)
	self.typeName = model:GetAttribute(TABLE_ATTR.TableType) or TableConfig.DefaultType
	self.config = TableConfig.get(self.typeName)
	self.state = GameConfig.States.Waiting

	self.seats = {} -- SeatIndex 순서로 정렬된 Seat 배열
	self.playerOfSeat = {} -- [Seat]   = Player
	self.seatOfPlayer = {} -- [Player] = Seat
	self.seatedCount = 0
	self.occupantConnections = {}
	self.destroyed = false

	self.cleaner = Utility.Cleaner.new()
	self.promptLimiter = Utility.RateLimiter.new(GameConfig.PromptCooldown)

	-- 인원이 바뀔 때마다 발생. Phase 2 의 RoundService 가 여기에 붙어 카운트다운을 켜고 끈다.
	-- (gameTable, player, joined) 형태로 전달된다.
	self.RosterChanged = self.cleaner:add(Utility.Signal.new())

	self:_collectSeats(seatsFolder)

	if #self.seats == 0 then
		warn(("[CursedBarrel] '%s' 의 Seats 폴더 안에 Seat 이 하나도 없습니다."):format(model:GetFullName()))
		self.cleaner:clean()
		return nil
	end

	self:_writeTableAttributes()
	self:_bindSeats()
	for _, seat in ipairs(self.seats) do self:_onOccupantChanged(seat) end
	self:_refresh()

	return self
end

function GameTable:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	-- 앉아 있던 사람들을 먼저 일으켜 세운다.
	-- 순회 중에 명단이 바뀌므로 목록을 복사해 두고 돈다.
	local seatedPlayers = {}
	for player in pairs(self.seatOfPlayer) do
		table.insert(seatedPlayers, player)
	end
	for _, player in ipairs(seatedPlayers) do
		self:RemovePlayer(player)
	end

	self.cleaner:clean()
	for _, seat in ipairs(self.seats) do
		local prompt = seat:FindFirstChild("SitPrompt")
		if prompt then prompt:Destroy() end
		CollectionService:RemoveTag(seat, GameConfig.Tags.Seat)
	end

	table.clear(self.seats)
	table.clear(self.playerOfSeat)
	table.clear(self.seatOfPlayer)

	self.model = nil
end

--------------------------------------------------
-- 초기화 내부 함수
--------------------------------------------------

function GameTable:_collectSeats(seatsFolder)
	for _, descendant in ipairs(seatsFolder:GetDescendants()) do
		if descendant:IsA("Seat") then
			table.insert(self.seats, descendant)
		end
	end

	-- SeatIndex Attribute 가 있으면 그 순서, 없으면 이름 순서로 정렬한다.
	table.sort(self.seats, function(a, b)
		local indexA = a:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		local indexB = b:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		if indexA == indexB then
			return a.Name < b.Name
		end
		return indexA < indexB
	end)

	-- 정렬 결과대로 번호를 다시 매긴다. (모델을 손으로 만들어도 항상 1..N 이 된다)
	for index, seat in ipairs(self.seats) do
		seat:SetAttribute(SEAT_ATTR.SeatIndex, index)
		seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
		seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
		CollectionService:AddTag(seat, GameConfig.Tags.Seat)
	end
end

function GameTable:_writeTableAttributes()
	local model = self.model
	model:SetAttribute(TABLE_ATTR.TableId, self.tableId)
	model:SetAttribute(TABLE_ATTR.TableType, self.typeName)
	model:SetAttribute(TABLE_ATTR.SeatCount, #self.seats)
	model:SetAttribute(TABLE_ATTR.MinPlayers, self:GetMinPlayers())
	model:SetAttribute(TABLE_ATTR.SeatedCount, 0)
	model:SetAttribute(TABLE_ATTR.State, self.state)

	-- Phase 2 : 값은 RoundService 가 채우지만, 자리는 여기서 미리 만들어 둔다.
	-- 클라이언트가 첫 프레임부터 nil 검사 없이 읽을 수 있다.
	model:SetAttribute(TABLE_ATTR.CountdownEndsAt, 0)
	model:SetAttribute(TABLE_ATTR.CountdownDuration, self.config.CountdownDuration or 0)
	model:SetAttribute(TABLE_ATTR.RoundId, 0)
	model:SetAttribute(TABLE_ATTR.ParticipantCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnIndex, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnUserId, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnName, "")
	model:SetAttribute(TABLE_ATTR.TurnEndsAt, 0)
end

function GameTable:_bindSeats()
	for _, seat in ipairs(self.seats) do
		local prompt = self:_ensurePrompt(seat)

		self.cleaner:add(prompt.Triggered:Connect(function(player)
			self:_onPromptTriggered(player, seat)
		end))

		-- 앉기/일어서기 판단은 오직 서버의 이 신호만 믿는다.
		self.cleaner:add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_onOccupantChanged(seat)
		end))
	end
end

-- Prompt 는 서버가 직접 만들어 붙인다.
-- 손으로 만든 모델이든 복제한 모델이든 설정이 항상 똑같이 맞춰진다.
function GameTable:_ensurePrompt(seat)
	local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.Parent = seat
	end

	local settings = GameConfig.SeatPrompt
	prompt.ActionText = settings.ActionText
	prompt.ObjectText = ("%s · %d번 자리"):format(self.config.DisplayName, seat:GetAttribute(SEAT_ATTR.SeatIndex) or 0)
	prompt.HoldDuration = settings.HoldDuration
	prompt.MaxActivationDistance = settings.MaxActivationDistance
	prompt.RequiresLineOfSight = settings.RequiresLineOfSight
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton

	return prompt
end

--------------------------------------------------
-- 좌석 이벤트
--------------------------------------------------

function GameTable:_onPromptTriggered(player, seat)
	-- 1) 연타 방지
	if not self.promptLimiter:check(player.UserId) then
		return
	end

	-- 2) 지금 참가 가능한 상태인가
	if self.destroyed or not self:IsJoinable() then
		return
	end

	-- 3) 이미 누가 앉아 있는 자리인가
	if seat.Occupant ~= nil then
		return
	end

	-- 4) 캐릭터가 멀쩡한가
	local humanoid = Utility.getHumanoid(player)
	if not humanoid then
		return
	end

	-- 5) 이미 어딘가에 앉아 있는가
	if humanoid.SeatPart then
		return
	end

	-- 6) 정말 자리 근처에 있는가 (클라이언트 거리 판정을 서버가 한 번 더 확인)
	local rootPart = humanoid.RootPart
	if not rootPart then
		return
	end

	local allowedDistance = GameConfig.SeatPrompt.MaxActivationDistance + 6
	if (rootPart.Position - seat.Position).Magnitude > allowedDistance then
		return
	end

	seat:Sit(humanoid)
end

function GameTable:_onOccupantChanged(seat)
	if self.destroyed then return end
	local occupant = seat.Occupant
	local previousPlayer = self.playerOfSeat[seat]

	-- 자리가 비었다 → 앉아 있던 사람을 명단에서 뺀다
	if not occupant then
		if previousPlayer then
			self:_unseat(previousPlayer, seat)
		end
		self:_refresh()
		return
	end

	local character = occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)

	-- 플레이어가 아닌 Humanoid(NPC 등)는 참가자로 세지 않는다
	if not player or player.Parent ~= Players or occupant.Health <= 0 then
		if previousPlayer then self:_unseat(previousPlayer, seat) end
		occupant.Sit = false
		self:_refresh()
		return
	end

	if previousPlayer == player then
		return
	end

	if previousPlayer then
		self:_unseat(previousPlayer, seat)
	end

	-- 진행 중인 테이블에는 난입할 수 없다 (익스플로잇으로 순간이동해 앉아도 튕겨낸다)
	if self.destroyed or not self:IsJoinable() then
		GameConfig.log(("%s 진행 중이라 %s 의 착석을 되돌립니다."):format(self.tableId, player.Name))
		task.defer(function()
			if seat.Occupant == occupant then
				occupant.Sit = false
			end
		end)
		return
	end

	self:_seat(player, seat)
end

function GameTable:_seat(player, seat)
	local previousTable = playerTables[player]
	if previousTable then
		local previousSeat = previousTable.seatOfPlayer[player]
		if previousSeat and (previousTable ~= self or previousSeat ~= seat) then
			previousTable:_unseat(player, previousSeat)
		end
	end
	playerTables[player] = self
	self.playerOfSeat[seat] = player
	self.seatOfPlayer[player] = seat
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, player.UserId)
	local connections = {}
	self.occupantConnections[seat] = connections
	local humanoid = seat.Occupant
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(function() self:RemovePlayer(player) end))
	end
	table.insert(connections, player.CharacterRemoving:Connect(function() self:RemovePlayer(player) end))

	GameConfig.log(("%s → %s %d번 자리에 앉음"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, true)
end

function GameTable:_unseat(player, seat)
	if self.playerOfSeat[seat] ~= player then
		return
	end

	self.playerOfSeat[seat] = nil
	if self.seatOfPlayer[player] == seat then self.seatOfPlayer[player] = nil end
	if playerTables[player] == self and not self.seatOfPlayer[player] then playerTables[player] = nil end
	for _, connection in ipairs(self.occupantConnections[seat] or {}) do connection:Disconnect() end
	self.occupantConnections[seat] = nil
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
	seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)

	GameConfig.log(("%s → %s %d번 자리에서 일어남"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, false)
end

-- 인원 수를 다시 세고 Attribute 와 Prompt 상태를 맞춘다.
function GameTable:_refresh()
	if not self.model then return end

	local count = 0
	for _, seat in ipairs(self.seats) do
		if self.playerOfSeat[seat] then
			count += 1
		end
	end

	self.seatedCount = count
	self.model:SetAttribute(TABLE_ATTR.SeatedCount, count)

	local joinable = self:IsJoinable()
	for _, seat in ipairs(self.seats) do
		local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not self.destroyed and joinable and seat.Occupant == nil
		end

		-- 참가 불가 상태에서는 '걸어가서 부딪혀 앉는' 것도 막는다.
		-- 단, 이미 앉아 있는 좌석은 건드리지 않는다.
		--   (게임 중인 참가자의 좌석을 Disabled 로 만들 필요가 없고,
		--    일어설 때의 기본 쿨다운도 방해하지 않는다)
		local shouldDisable = (not joinable) and seat.Occupant == nil
		if seat.Disabled ~= shouldDisable then
			seat.Disabled = shouldDisable
		end
	end
end

--------------------------------------------------
-- 공개 API (RoundService 가 사용한다)
--------------------------------------------------

function GameTable:IsJoinable()
	return GameConfig.JoinableStates[self.state] == true
end

function GameTable:GetPlayerCount()
	return self.seatedCount
end

-- 이 테이블에서 카운트다운을 시작/유지하는 데 필요한 인원.
-- 좌석 수보다 큰 값이 설정돼 있으면 영원히 시작되지 않으므로 좌석 수로 잘라준다.
function GameTable:GetMinPlayers()
	local configured = tonumber(self.config.MinPlayers) or 2
	return math.max(1, math.min(configured, #self.seats))
end

-- 좌석 번호 순서대로 정렬된 참가자 목록
function GameTable:GetPlayers()
	local list = {}
	for _, seat in ipairs(self.seats) do
		local player = self.playerOfSeat[seat]
		if player then
			table.insert(list, player)
		end
	end
	return list
end

function GameTable:GetSeats()
	return self.seats
end

function GameTable:GetPlayerOfSeat(seat)
	return self.playerOfSeat[seat]
end

function GameTable:HasPlayer(player)
	return self.seatOfPlayer[player] ~= nil
end

function GameTable:GetSeatOfPlayer(player)
	return self.seatOfPlayer[player]
end

-- 파괴된 뒤에 늦게 도착한 호출이 있어도 오류가 나지 않도록 감싼다.
function GameTable:SetTableAttribute(name, value)
	if self.destroyed or not self.model then
		return false
	end
	self.model:SetAttribute(name, value)
	return true
end

function GameTable:SetState(newState)
	if self.state == newState then
		return
	end

	self.state = newState
	if self.model then
		self.model:SetAttribute(TABLE_ATTR.State, newState)
	end
	self:_refresh()

	GameConfig.log(("%s 상태 → %s"):format(self.tableId, newState))
end

-- 플레이어를 자리에서 강제로 일으켜 세운다.
function GameTable:RemovePlayer(player)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end

	local humanoid = seat.Occupant
	if humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) == player then
		-- Occupant 변경 신호가 뒷정리를 대신 해준다.
		humanoid.Sit = false
	end

	-- 캐릭터가 이미 사라진 경우를 대비해 직접 정리도 해둔다.
	self:_unseat(player, seat)
	return true
end

-- 플레이어가 게임을 나갈 때 호출된다.
function GameTable:HandlePlayerRemoving(player)
	self.promptLimiter:forget(player.UserId)
	self:RemovePlayer(player)
	if playerTables[player] == self then
		playerTables[player] = nil
	end
end

return GameTable
]====]
SOURCES.TableService = [====[
--[[
	TableService
	Workspace 에 있는 모든 게임 테이블을 찾아 GameTable 객체로 만들어 관리한다.

	CollectionService 태그 기반이라
	테이블 모델을 복제해서 Workspace 에 놓고 태그만 붙이면 자동으로 등록된다.
	(Table01, Table02 같은 이름 하드코딩 없음)

	Phase 2 추가
	  - TableAdded / TableRemoved 신호. RoundService 가 이 신호를 듣고
	    테이블마다 라운드 진행 담당자를 하나씩 붙였다 떼었다 한다.
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
]====]
SOURCES.RoundService = [====[
--[[
	RoundService
	Phase 2 의 핵심.

	테이블 하나마다 "라운드 진행 담당자(Round)"를 붙여서 아래를 처리한다.
	  1. 최소 인원이 앉으면 카운트다운 시작
	  2. 인원이 최소 인원 밑으로 떨어지면 카운트다운 즉시 취소
	  3. 남은 시간은 테이블 Attribute(CountdownEndsAt)로 알려준다 → 현황판이 읽어 그린다
	  4. 카운트다운이 끝나면 참가자를 확정하고 상태를 Playing 으로 바꾼다
	  5. 턴 순서는 서버가 무작위로 섞어서 정한다
	  6. 현재 차례인 사람을 테이블 Attribute 로 알린다
	  7. Playing 이 되는 순간부터 새 참가자는 앉을 수 없다 (GameTable:IsJoinable)
	  8. 참가자가 나가거나 캐릭터가 리셋돼도 명단과 턴 순서를 조용히 정리한다

	판정과 상태 변경은 전부 서버(이 파일)에서만 일어난다.
	클라이언트는 Attribute 를 읽어 보여주기만 하므로 조작할 수 있는 통로가 없다.

	테이블마다 Round 객체가 따로 있으므로, 테이블을 복제해도 서로 간섭하지 않는다.

	Phase 3 예고
	  - 칼 슬롯 선택 / 위험 판정 / 탈락 / 승리는 아직 없다.
	  - 준비된 연결 고리: Round:AdvanceTurn(), Round:RemoveParticipant(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States

--------------------------------------------------
-- Round : 테이블 하나의 라운드 상태
--------------------------------------------------
local Round = {}
Round.__index = Round

function Round.new(gameTable)
	local self = setmetatable({}, Round)

	self.gameTable = gameTable
	self.cleaner = Utility.Cleaner.new()
	self.random = Random.new() -- 턴 순서를 섞을 때 쓰는 서버 전용 난수

	self.participants = {} -- 턴 순서대로 정렬된 참가자 배열
	self.isParticipant = {} -- [Player] = true (빠른 조회용)
	self.turnIndex = 0
	self.roundId = 0
	self.destroyed = false

	-- 예약한 작업을 취소하는 대신 토큰을 하나 올린다.
	-- 늦게 도착한 task.delay 콜백은 토큰이 다르면 스스로 물러난다.
	-- (타이머를 직접 취소할 수 없는 Roblox 에서 가장 오류가 적은 방식)
	self.countdownToken = 0
	self.turnToken = 0

	self.cleaner:add(gameTable.RosterChanged:Connect(function(_, player, joined)
		self:_onRosterChanged(player, joined)
	end))

	self:_resetRoundAttributes()
	self:_evaluate() -- 서버 시작 시 이미 앉아 있는 사람이 있을 수 있다

	return self
end

function Round:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.countdownToken += 1
	self.turnToken += 1

	self.cleaner:clean()
	table.clear(self.participants)
	table.clear(self.isParticipant)
end

--------------------------------------------------
-- Attribute 기록 (클라이언트가 읽는 유일한 통로)
--------------------------------------------------

function Round:_set(name, value)
	self.gameTable:SetTableAttribute(name, value)
end

function Round:_minPlayers()
	return self.gameTable:GetMinPlayers()
end

-- 좌석마다 이번 라운드의 턴 순서를 적어둔다. (참가자가 아니면 0)
function Round:_writeSeatOrder()
	local orderOfPlayer = {}
	for index, player in ipairs(self.participants) do
		orderOfPlayer[player] = index
	end

	for _, seat in ipairs(self.gameTable:GetSeats()) do
		local player = self.gameTable:GetPlayerOfSeat(seat)
		local order = (player and orderOfPlayer[player]) or 0
		if seat:GetAttribute(SEAT_ATTR.TurnOrder) ~= order then
			seat:SetAttribute(SEAT_ATTR.TurnOrder, order)
		end
	end
end

function Round:_resetRoundAttributes()
	self:_set(TABLE_ATTR.CountdownEndsAt, 0)
	self:_set(TABLE_ATTR.CountdownDuration, tonumber(self.gameTable.config.CountdownDuration) or 0)
	self:_set(TABLE_ATTR.ParticipantCount, 0)
	self:_set(TABLE_ATTR.TurnCount, 0)
	self:_set(TABLE_ATTR.TurnIndex, 0)
	self:_set(TABLE_ATTR.CurrentTurnUserId, 0)
	self:_set(TABLE_ATTR.CurrentTurnName, "")
	self:_set(TABLE_ATTR.TurnEndsAt, 0)
	self:_writeSeatOrder()
end

--------------------------------------------------
-- 상태 판단
--------------------------------------------------

-- 인원이 바뀔 때마다 "지금 뭘 해야 하는지"를 한 곳에서 결정한다.
function Round:_evaluate()
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local state = self.gameTable.state
	local seated = self.gameTable:GetPlayerCount()
	local minPlayers = self:_minPlayers()

	if state == STATES.Waiting then
		if seated >= minPlayers then
			self:_startCountdown()
		end
	elseif state == STATES.Countdown then
		if seated < minPlayers then
			self:_cancelCountdown()
		end
	end
	-- Playing 중의 인원 변화는 _removeParticipant 가 따로 처리한다.
end

--------------------------------------------------
-- 카운트다운
--------------------------------------------------

function Round:_startCountdown()
	local duration = tonumber(self.gameTable.config.CountdownDuration) or 5
	if duration <= 0 then
		duration = 0.1
	end

	self.countdownToken += 1
	local token = self.countdownToken

	self.gameTable:SetState(STATES.Countdown)
	self:_set(TABLE_ATTR.CountdownDuration, duration)
	self:_set(TABLE_ATTR.CountdownEndsAt, GameConfig.now() + duration)

	GameConfig.log(("%s 카운트다운 시작 · %.1f초 · 인원 %d/%d")
		:format(self.gameTable.tableId, duration, self.gameTable:GetPlayerCount(), self:_minPlayers()))

	task.delay(duration, function()
		-- 그 사이 취소됐거나(토큰 변경), 테이블이 사라졌거나, 상태가 바뀌었으면 아무것도 하지 않는다.
		if self.destroyed or token ~= self.countdownToken then
			return
		end
		if self.gameTable.destroyed or self.gameTable.state ~= STATES.Countdown then
			return
		end

		-- 마지막으로 한 번 더 인원을 확인한다. (같은 프레임에 빠져나간 경우 대비)
		if self.gameTable:GetPlayerCount() < self:_minPlayers() then
			self:_cancelCountdown()
			return
		end

		self:_beginRound()
	end)
end

function Round:_cancelCountdown()
	self.countdownToken += 1 -- 예약된 시작을 무효로 만든다
	self:_set(TABLE_ATTR.CountdownEndsAt, 0)

	if not self.gameTable.destroyed and self.gameTable.state == STATES.Countdown then
		self.gameTable:SetState(STATES.Waiting)
	end

	GameConfig.log(("%s 카운트다운 취소 · 인원 %d/%d")
		:format(self.gameTable.tableId, self.gameTable:GetPlayerCount(), self:_minPlayers()))
end

--------------------------------------------------
-- 라운드 시작
--------------------------------------------------

function Round:_beginRound()
	-- 1) 이 순간 앉아 있는 사람들을 참가자로 확정한다.
	local participants = self.gameTable:GetPlayers()

	-- 2) 턴 순서는 서버에서 무작위로 섞는다. (좌석 순서를 알아도 예측할 수 없다)
	Utility.shuffle(participants, self.random)

	self.participants = participants
	table.clear(self.isParticipant)
	for _, player in ipairs(participants) do
		self.isParticipant[player] = true
	end

	self.roundId += 1
	self.turnIndex = 0

	self:_set(TABLE_ATTR.CountdownEndsAt, 0)
	self:_set(TABLE_ATTR.RoundId, self.roundId)
	self:_set(TABLE_ATTR.ParticipantCount, #participants)
	self:_set(TABLE_ATTR.TurnCount, #participants)
	self:_writeSeatOrder()

	-- 3) 상태를 Playing 으로. 이 순간부터 빈 의자에도 앉을 수 없다.
	self.gameTable:SetState(STATES.Playing)

	local names = {}
	for _, player in ipairs(participants) do
		table.insert(names, player.Name)
	end
	GameConfig.log(("%s 라운드 %d 시작 · 턴 순서: %s")
		:format(self.gameTable.tableId, self.roundId, table.concat(names, " → ")))

	-- 4) 첫 번째 차례
	self:_beginTurn(1)
end

-- Phase 2 에는 승리 판정이 없다. 여기서는 "테이블을 다시 쓸 수 있게 정리"만 한다.
-- Phase 3 에서 이 자리가 승자 발표 / RoundEnding 연출로 바뀐다.
function Round:_finishRound(reason)
	self.countdownToken += 1
	self.turnToken += 1

	table.clear(self.participants)
	table.clear(self.isParticipant)
	self.turnIndex = 0

	self:_resetRoundAttributes()

	if not self.gameTable.destroyed then
		self.gameTable:SetState(STATES.Waiting)
	end

	GameConfig.log(("%s 라운드 정리 (%s)"):format(self.gameTable.tableId, tostring(reason)))

	-- 아직 앉아 있는 사람이 있으면 곧바로 새 카운트다운이 시작된다.
	self:_evaluate()
end

--------------------------------------------------
-- 턴
--------------------------------------------------

function Round:_beginTurn(index)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local count = #self.participants
	if count == 0 then
		self:_finishRound("참가자가 모두 자리를 떠남")
		return
	end

	-- 목록 끝을 넘어가면 처음으로 돌아온다.
	index = ((index - 1) % count) + 1
	self.turnIndex = index

	local player = self.participants[index]

	self.turnToken += 1
	local token = self.turnToken

	self:_set(TABLE_ATTR.TurnIndex, index)
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_set(TABLE_ATTR.CurrentTurnUserId, player.UserId)
	self:_set(TABLE_ATTR.CurrentTurnName, player.DisplayName or player.Name)

	local duration = tonumber(self.gameTable.config.TurnDuration) or 0
	if self.gameTable.config.AutoAdvanceTurn and duration > 0 then
		self:_set(TABLE_ATTR.TurnEndsAt, GameConfig.now() + duration)
		task.delay(duration, function()
			if self.destroyed or token ~= self.turnToken then
				return
			end
			if self.gameTable.destroyed or self.gameTable.state ~= STATES.Playing then
				return
			end
			-- Phase 3 에서는 "제한 시간 안에 칼을 고르지 못함" 처리가 여기에 들어간다.
			self:AdvanceTurn()
		end)
	else
		self:_set(TABLE_ATTR.TurnEndsAt, 0)
	end

	GameConfig.log(("%s 턴 %d/%d · %s"):format(self.gameTable.tableId, index, count, player.Name))
end

-- 다음 사람에게 차례를 넘긴다. (Phase 3 에서 칼을 뽑은 뒤 호출하게 된다)
function Round:AdvanceTurn()
	if self.destroyed or self.gameTable.destroyed then
		return
	end
	if self.gameTable.state ~= STATES.Playing then
		return
	end
	self:_beginTurn(self.turnIndex + 1)
end

--------------------------------------------------
-- 참가자 이탈 (퇴장 / 캐릭터 리셋 / 강제 일어나기)
--------------------------------------------------

function Round:RemoveParticipant(player)
	local index = table.find(self.participants, player)
	self.isParticipant[player] = nil

	if not index then
		self:_writeSeatOrder()
		return false
	end

	table.remove(self.participants, index)

	local count = #self.participants
	self:_set(TABLE_ATTR.ParticipantCount, count)
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_writeSeatOrder()

	GameConfig.log(("%s 참가자 이탈: %s · 남은 인원 %d명")
		:format(self.gameTable.tableId, player.Name, count))

	if self.gameTable.state ~= STATES.Playing then
		return true
	end

	if count < self:_minPlayers() then
		-- 남은 인원으로는 게임을 이어갈 수 없다.
		-- Phase 2 에는 승리 판정이 없으므로 테이블이 잠기지 않도록 정리만 한다.
		self:_finishRound("남은 인원이 최소 인원보다 적음")
		return true
	end

	if index < self.turnIndex then
		-- 내 앞 순서가 빠졌으니 현재 차례의 번호가 하나 당겨진다.
		self.turnIndex -= 1
		self:_set(TABLE_ATTR.TurnIndex, self.turnIndex)
	elseif index == self.turnIndex then
		-- 차례이던 사람이 나갔다 → 그 자리로 밀려온 다음 사람부터 이어서 진행
		self:_beginTurn(index)
	end

	return true
end

function Round:_onRosterChanged(player, joined)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	if joined then
		-- 게임 중의 착석은 GameTable 이 이미 막는다.
		-- 여기서는 대기/카운트다운 상태만 다시 판단하면 된다.
		self:_writeSeatOrder()
		self:_evaluate()
		return
	end

	if self.isParticipant[player] then
		self:RemoveParticipant(player)
	else
		self:_writeSeatOrder()
	end

	self:_evaluate()
end

--------------------------------------------------
-- 조회 API
--------------------------------------------------

function Round:GetParticipants()
	return table.clone(self.participants)
end

function Round:GetCurrentPlayer()
	return self.participants[self.turnIndex]
end

function Round:IsPlayerTurn(player)
	return self:GetCurrentPlayer() == player
end

--------------------------------------------------
-- RoundService : 테이블마다 Round 를 하나씩 붙인다
--------------------------------------------------

local RoundService = {}
RoundService._rounds = {} -- [GameTable] = Round
RoundService._cleaner = Utility.Cleaner.new()
RoundService._started = false

function RoundService:_attach(gameTable)
	if self._rounds[gameTable] or gameTable.destroyed then
		return
	end

	local ok, result = pcall(Round.new, gameTable)
	if not ok then
		warn(("[CursedBarrel] 라운드 담당 생성 실패 (%s): %s"):format(tostring(gameTable.tableId), tostring(result)))
		return
	end

	self._rounds[gameTable] = result
	GameConfig.log(("라운드 담당 등록: %s"):format(tostring(gameTable.tableId)))
end

function RoundService:_detach(gameTable)
	local round = self._rounds[gameTable]
	if not round then
		return
	end

	self._rounds[gameTable] = nil

	local ok, err = pcall(function()
		round:Destroy()
	end)
	if not ok then
		warn("[CursedBarrel] 라운드 정리 중 오류: " .. tostring(err))
	end
end

function RoundService:Start()
	if self._started then
		return
	end
	self._started = true

	self._cleaner:add(TableService.TableAdded:Connect(function(gameTable)
		self:_attach(gameTable)
	end))

	self._cleaner:add(TableService.TableRemoved:Connect(function(gameTable)
		self:_detach(gameTable)
	end))

	-- TableService 가 먼저 시작됐더라도 빠뜨리지 않도록 이미 등록된 테이블을 훑는다.
	for _, gameTable in ipairs(TableService:GetAllTables()) do
		self:_attach(gameTable)
	end

	GameConfig.log("RoundService 시작 완료")
end

function RoundService:GetRound(gameTable)
	return self._rounds[gameTable]
end

function RoundService:GetRoundOfPlayer(player)
	local gameTable = TableService:GetTableOfPlayer(player)
	if not gameTable then
		return nil
	end
	return self._rounds[gameTable]
end

return RoundService
]====]
SOURCES.Main = [====[
--[[
	Main
	서버 진입점. 서비스들을 순서대로 켜는 일만 한다.

	위치: ServerScriptService > CursedBarrel > Main  (Script)
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("CursedBarrel"):WaitForChild("Services")
local TableService = require(Services.TableService)
local RoundService = require(Services.RoundService)

-- 테이블을 먼저 찾아 등록하고, 그 다음 라운드 담당자를 붙인다.
-- (순서가 바뀌어도 RoundService 가 기존 테이블을 훑기 때문에 문제는 없다)
TableService:Start()
RoundService:Start()

print("[CursedBarrel] 서버 부팅 완료 (Phase 2: 카운트다운 · 라운드 시작 · 턴 순서)")
]====]
SOURCES.TableController = [====[
--[[
	TableController
	테이블 위에 떠 있는 현황판(0/4, 카운트다운, 현재 차례)을 그린다.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > TableController  (LocalScript)

	서버는 테이블 모델의 Attribute 만 바꾸고, 클라이언트는 그 값을 읽어 UI 를 만든다.
	→ RemoteEvent 가 필요 없고, UI 연산은 각자 기기에서만 일어난다.

	Phase 2 에서 늘어난 표시
	  - 남은 카운트다운 시간 (큰 숫자 + 게이지)
	  - 현재 차례인 플레이어 이름 / 내 차례 강조
	  - 턴 제한 시간 게이지
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

--------------------------------------------------
-- 색상 팔레트 (해적 선술집: 어두운 나무 + 금색 포인트)
--------------------------------------------------
local PALETTE = {
	Wood = Color3.fromRGB(38, 25, 18),
	WoodLight = Color3.fromRGB(74, 49, 32),
	Gold = Color3.fromRGB(226, 178, 86),
	Cream = Color3.fromRGB(238, 223, 196),
	Ready = Color3.fromRGB(131, 209, 144),
	Mine = Color3.fromRGB(255, 214, 122),
	Danger = Color3.fromRGB(226, 122, 106),
}

local COUNT_SIZE = UDim2.fromScale(1, 0.34)
local COUNT_POP = UDim2.fromScale(1.14, 0.4)
local POP_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local STATE_TEXT = {
	[STATES.Starting] = "게임 시작!",
	[STATES.Playing] = "게임 진행 중",
	[STATES.RoundEnding] = "라운드 종료",
	[STATES.Resetting] = "정리하는 중...",
}

local boards = {} -- [Model] = entry

--------------------------------------------------
-- UI 만들기
--------------------------------------------------

local function createLabel(parent, name, size, position, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = PALETTE.Cream
	label.Text = ""
	label.Parent = parent

	-- TextScaled 가 너무 커지지 않도록 상한을 둔다
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label

	return label
end

-- 카운트다운 / 턴 제한시간을 보여주는 가느다란 게이지
local function createTimerBar(parent)
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.63)
	track.Size = UDim2.fromScale(0.74, 0.06)
	track.BackgroundColor3 = PALETTE.Wood
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = parent

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = PALETTE.Gold
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return track, fill
end

local function buildBoard(adornee)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CursedBarrel_TableBoard"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromScale(7.8, 4.4) -- 스터드 기준 크기
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = PALETTE.Wood
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.16, 0)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(PALETTE.WoodLight, PALETTE.Wood)
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Color = PALETTE.Gold
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = frame

	local title = createLabel(frame, "Title", UDim2.fromScale(0.92, 0.17), UDim2.fromScale(0.5, 0.12), 22)
	title.Font = Enum.Font.GothamMedium
	title.TextColor3 = PALETTE.Gold
	title.TextTransparency = 0.1

	local count = createLabel(frame, "Count", COUNT_SIZE, UDim2.fromScale(0.5, 0.39), 54)
	count.Font = Enum.Font.GothamBlack

	local track, fill = createTimerBar(frame)

	local status = createLabel(frame, "Status", UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.5, 0.79), 20)
	status.Font = Enum.Font.GothamMedium

	local turn = createLabel(frame, "Turn", UDim2.fromScale(0.92, 0.15), UDim2.fromScale(0.5, 0.94), 19)
	turn.Font = Enum.Font.GothamBold
	turn.Visible = false

	return {
		billboard = billboard,
		frame = frame,
		stroke = stroke,
		title = title,
		count = count,
		status = status,
		turn = turn,
		timerTrack = track,
		timerFill = fill,
	}
end

--------------------------------------------------
-- 갱신
--------------------------------------------------

local function isLocalPlayerSeated(entry)
	for _, seat in ipairs(entry.seats) do
		if seat:GetAttribute(SEAT_ATTR.OccupantUserId) == localPlayer.UserId then
			return true
		end
	end
	return false
end

-- Attribute 가 바뀔 때만 부르는 "느린" 갱신
local function updateBoard(entry)
	local model = entry.model
	if not model or not model.Parent then
		return
	end

	local seated = model:GetAttribute(TABLE_ATTR.SeatedCount) or 0
	local capacity = model:GetAttribute(TABLE_ATTR.SeatCount) or 0
	local minPlayers = model:GetAttribute(TABLE_ATTR.MinPlayers) or 1
	local state = model:GetAttribute(TABLE_ATTR.State) or STATES.Waiting

	entry.state = state
	entry.seated = seated
	entry.capacity = capacity

	local preset = TableConfig.get(model:GetAttribute(TABLE_ATTR.TableType))
	entry.title.Text = preset.DisplayName

	local statusText, statusColor

	if state == STATES.Countdown then
		-- 남은 시간(숫자/게이지)은 updateTimer 가 매 프레임 채운다
		statusText = ("%d명 참가 · 곧 시작합니다"):format(seated)
		statusColor = PALETTE.Gold
	elseif GameConfig.InGameStates[state] then
		entry.count.Text = ("%d / %d"):format(seated, capacity)
		entry.count.TextColor3 = PALETTE.Cream
		statusText = STATE_TEXT[state] or "게임 진행 중"
		statusColor = PALETTE.Danger
	else
		entry.count.Text = ("%d / %d"):format(seated, capacity)
		entry.count.TextColor3 = PALETTE.Cream
		if seated == 0 then
			statusText, statusColor = "빈 테이블 · 앉으면 참가", PALETTE.Cream
		elseif seated < minPlayers then
			statusText, statusColor = ("%d명 더 필요"):format(minPlayers - seated), PALETTE.Cream
		else
			statusText, statusColor = "시작 준비 완료", PALETTE.Ready
		end
	end

	entry.status.Text = statusText
	entry.status.TextColor3 = statusColor

	-- 현재 차례 표시
	local turnUserId = model:GetAttribute(TABLE_ATTR.CurrentTurnUserId) or 0
	local turnName = model:GetAttribute(TABLE_ATTR.CurrentTurnName) or ""
	local turnIndex = model:GetAttribute(TABLE_ATTR.TurnIndex) or 0
	local turnCount = model:GetAttribute(TABLE_ATTR.TurnCount) or 0
	local showTurn = GameConfig.InGameStates[state] == true and turnUserId ~= 0 and turnName ~= ""

	entry.turn.Visible = showTurn
	if showTurn then
		if turnUserId == localPlayer.UserId then
			entry.turn.Text = ("▶ 내 차례! (%d/%d)"):format(turnIndex, turnCount)
			entry.turn.TextColor3 = PALETTE.Mine
		else
			entry.turn.Text = ("▶ %s 님의 차례 (%d/%d)"):format(turnName, turnIndex, turnCount)
			entry.turn.TextColor3 = PALETTE.Cream
		end
	end

	-- 내가 앉아 있는 테이블은 테두리를 금색으로 밝혀 구분한다
	local mine = isLocalPlayerSeated(entry)
	local myTurn = mine and turnUserId == localPlayer.UserId
	local highlight = myTurn and "turn" or (mine and "mine" or "none")
	if entry.highlight ~= highlight then
		entry.highlight = highlight
		TweenService:Create(entry.stroke, FADE_TWEEN, {
			Thickness = (highlight == "turn" and 5) or (highlight == "mine" and 3.5) or 2,
			Transparency = highlight == "none" and 0.3 or 0,
			Color = highlight == "none" and PALETTE.Gold or PALETTE.Mine,
		}):Play()
	end

	-- 인원이 바뀌면 숫자가 살짝 튀어오른다 (카운트다운 중에는 타이머가 따로 연출한다)
	if entry.lastCount ~= seated then
		entry.lastCount = seated
		if state ~= STATES.Countdown then
			entry.count.Size = COUNT_POP
			TweenService:Create(entry.count, POP_TWEEN, { Size = COUNT_SIZE }):Play()
		end
	end
end

-- 남은 시간을 그리는 "빠른" 갱신. 서버 시계를 기준으로 계산하므로
-- 서버가 매 초 Attribute 를 갱신하지 않아도 화면은 부드럽게 흐른다.
local function updateTimer(entry)
	local model = entry.model
	if not model or not model.Parent then
		return
	end

	local state = entry.state
	local now = GameConfig.now()

	if state == STATES.Countdown then
		local endsAt = model:GetAttribute(TABLE_ATTR.CountdownEndsAt) or 0
		local duration = model:GetAttribute(TABLE_ATTR.CountdownDuration) or 0
		local remaining = math.max(0, endsAt - now)

		entry.count.Text = Utility.formatSeconds(remaining)
		entry.count.TextColor3 = PALETTE.Gold
		entry.timerTrack.Visible = true
		entry.timerFill.BackgroundColor3 = PALETTE.Gold
		entry.timerFill.Size = UDim2.fromScale(duration > 0 and math.clamp(remaining / duration, 0, 1) or 0, 1)

		-- 1초가 넘어갈 때마다 숫자가 한 번씩 뛴다
		local tick = math.ceil(remaining)
		if entry.lastTick ~= tick then
			entry.lastTick = tick
			entry.count.Size = COUNT_POP
			TweenService:Create(entry.count, POP_TWEEN, { Size = COUNT_SIZE }):Play()
		end
		return
	end

	entry.lastTick = nil

	if GameConfig.InGameStates[state] then
		local turnEndsAt = model:GetAttribute(TABLE_ATTR.TurnEndsAt) or 0
		local turnDuration = TableConfig.get(model:GetAttribute(TABLE_ATTR.TableType)).TurnDuration or 0
		if turnEndsAt > 0 and turnDuration > 0 then
			local remaining = math.max(0, turnEndsAt - now)
			entry.timerTrack.Visible = true
			entry.timerFill.BackgroundColor3 = remaining <= 2 and PALETTE.Danger or PALETTE.Ready
			entry.timerFill.Size = UDim2.fromScale(math.clamp(remaining / turnDuration, 0, 1), 1)
			return
		end
	end

	entry.timerTrack.Visible = false
end

--------------------------------------------------
-- 테이블 등록 / 해제
--------------------------------------------------

local function findAdornee(model)
	return model:FindFirstChild("StatusAnchor", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function registerTable(model)
	if boards[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
		return
	end

	local adornee = findAdornee(model)
	if not adornee then
		warn(("[CursedBarrel] '%s' 에 현황판을 붙일 Part 가 없습니다."):format(model:GetFullName()))
		return
	end

	local entry = buildBoard(adornee)
	entry.model = model
	entry.seats = {}
	entry.cleaner = Utility.Cleaner.new()
	entry.cleaner:add(entry.billboard)

	boards[model] = entry

	-- 테이블 Attribute 변화 구독
	for _, attributeName in ipairs({
		TABLE_ATTR.TableId,
		TABLE_ATTR.TableType,
		TABLE_ATTR.SeatCount,
		TABLE_ATTR.SeatedCount,
		TABLE_ATTR.MinPlayers,
		TABLE_ATTR.State,
		TABLE_ATTR.CountdownEndsAt,
		TABLE_ATTR.CountdownDuration,
		TABLE_ATTR.RoundId,
		TABLE_ATTR.ParticipantCount,
		TABLE_ATTR.TurnCount,
		TABLE_ATTR.TurnIndex,
		TABLE_ATTR.CurrentTurnUserId,
		TABLE_ATTR.CurrentTurnName,
	}) do
		entry.cleaner:add(model:GetAttributeChangedSignal(attributeName):Connect(function()
			updateBoard(entry)
		end))
	end

	-- 좌석 점유 변화 구독 (내가 앉은 테이블 강조용)
	local seatsFolder = model:FindFirstChild("Seats")
	if seatsFolder then
		for _, descendant in ipairs(seatsFolder:GetDescendants()) do
			if descendant:IsA("Seat") then
				table.insert(entry.seats, descendant)
				entry.cleaner:add(descendant:GetAttributeChangedSignal(SEAT_ATTR.OccupantUserId):Connect(function()
					updateBoard(entry)
				end))
			end
		end
	end

	updateBoard(entry)
	updateTimer(entry)
end

local function unregisterTable(model)
	local entry = boards[model]
	if not entry then
		return
	end

	boards[model] = nil
	entry.cleaner:clean()
end

--------------------------------------------------
-- 시작
--------------------------------------------------

for _, model in ipairs(CollectionService:GetTagged(TABLE_TAG)) do
	registerTable(model)
end

CollectionService:GetInstanceAddedSignal(TABLE_TAG):Connect(registerTable)
CollectionService:GetInstanceRemovedSignal(TABLE_TAG):Connect(unregisterTable)
workspace.DescendantAdded:Connect(function(instance)
	local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
	while model and model ~= workspace do
		if model:IsA("Model") and CollectionService:HasTag(model, TABLE_TAG) then
			task.defer(function()
				if model:IsDescendantOf(workspace) and CollectionService:HasTag(model, TABLE_TAG) then
					unregisterTable(model)
					registerTable(model)
				end
			end)
			break
		end
		model = model.Parent
	end
end)
workspace.DescendantRemoving:Connect(function(instance)
	if boards[instance] then unregisterTable(instance) end
end)

-- 남은 시간 표시는 초당 20번이면 충분하다. (테이블이 몇 개든 가벼운 계산만 한다)
local lastTimerUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTimerUpdate < 0.05 then
		return
	end
	lastTimerUpdate = now

	for _, entry in pairs(boards) do
		updateTimer(entry)
	end
end)
]====]
SOURCES.LightingController = [====[
--[[
	LightingController
	로비는 밝게, 내가 앉은 테이블의 게임이 시작되면 어둡게.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > LightingController  (LocalScript)

	왜 클라이언트에서 하나?
	  로비는 구매한 스킨/디자인을 전시하는 곳이라 밝아야 하고,
	  어두운 연출은 "게임에 참가한 사람" 화면에서만 필요하기 때문이다.
	  조명을 서버에서 바꾸면 로비에 있는 사람 화면까지 같이 어두워진다.
	  Lighting 을 클라이언트에서 바꾸면 내 화면에만 적용된다.

	프리셋 값은 GameConfig.Lighting 에 모여 있다. (설치 스크립트의 로비 조명과 같은 값)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local PRESETS = GameConfig.Lighting

local localPlayer = Players.LocalPlayer

local LIGHTING_KEYS = {
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"ClockTime",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
}

local TWEEN = TweenInfo.new(PRESETS.TweenTime or 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------
-- 프리셋 적용
--------------------------------------------------

-- 설치 스크립트가 만들어 둔 효과를 찾고, 없으면 내 화면에만 하나 만든다.
local function ensureEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local function tweenProperties(instance, properties)
	local goal = {}
	local hasAny = false
	for key, value in pairs(properties) do
		goal[key] = value
		hasAny = true
	end
	if not hasAny then
		return
	end

	local ok, err = pcall(function()
		TweenService:Create(instance, TWEEN, goal):Play()
	end)
	if not ok then
		warn("[CursedBarrel] 조명 전환 실패: " .. tostring(err))
	end
end

local function applyPreset(preset)
	local base = {}
	for _, key in ipairs(LIGHTING_KEYS) do
		if preset[key] ~= nil then
			base[key] = preset[key]
		end
	end
	tweenProperties(Lighting, base)

	if preset.Atmosphere then
		tweenProperties(ensureEffect("Atmosphere", "Atmosphere"), preset.Atmosphere)
	end
	if preset.Bloom then
		tweenProperties(ensureEffect("BloomEffect", "Bloom"), preset.Bloom)
	end
	if preset.ColorCorrection then
		tweenProperties(ensureEffect("ColorCorrectionEffect", "ColorCorrection"), preset.ColorCorrection)
	end
end

--------------------------------------------------
-- 지금 어떤 조명이어야 하는가
--------------------------------------------------

local currentMode = nil
local currentTable = nil
local tableCleaner = Utility.Cleaner.new()

local function setMode(mode)
	if currentMode == mode then
		return
	end
	currentMode = mode

	applyPreset(mode == "Game" and PRESETS.Game or PRESETS.Lobby)
	GameConfig.log("조명 전환 → " .. mode)
end

local function refresh()
	local model = currentTable
	if model and not model.Parent then
		model = nil
	end

	local state = model and model:GetAttribute(TABLE_ATTR.State)
	local inGame = state ~= nil and GameConfig.InGameStates[state] == true
	setMode(inGame and "Game" or "Lobby")
end

local function bindTable(model)
	if currentTable == model then
		refresh()
		return
	end

	tableCleaner:clean()
	currentTable = model

	if model then
		tableCleaner:add(model:GetAttributeChangedSignal(TABLE_ATTR.State):Connect(refresh))
		tableCleaner:add(model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				bindTable(nil)
			end
		end))
	end

	refresh()
end

-- 내가 앉은 좌석이 속한 "테이블 모델"을 위로 거슬러 올라가며 찾는다.
local function findTableFromSeat(seatPart)
	if not seatPart then
		return nil
	end

	local node = seatPart.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, TABLE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

--------------------------------------------------
-- 내 캐릭터 감시
--------------------------------------------------

local characterCleaner = Utility.Cleaner.new()

local function watchCharacter(character)
	characterCleaner:clean()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		bindTable(nil)
		return
	end

	local function onSeatChanged()
		bindTable(findTableFromSeat(humanoid.SeatPart))
	end

	characterCleaner:add(humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged))
	characterCleaner:add(humanoid.Died:Connect(function()
		bindTable(nil)
	end))

	onSeatChanged()
end

localPlayer.CharacterAdded:Connect(watchCharacter)
localPlayer.CharacterRemoving:Connect(function()
	characterCleaner:clean()
	bindTable(nil)
end)

if localPlayer.Character then
	task.spawn(watchCharacter, localPlayer.Character)
end

--------------------------------------------------
-- 시작
--------------------------------------------------

if PRESETS.ApplyLobbyOnJoin then
	-- 첫 적용은 트윈 없이 즉시. (접속하자마자 밝은 로비를 보게 된다)
	currentMode = "Lobby"
	for _, key in ipairs(LIGHTING_KEYS) do
		if PRESETS.Lobby[key] ~= nil then
			pcall(function()
				Lighting[key] = PRESETS.Lobby[key]
			end)
		end
	end
	applyPreset(PRESETS.Lobby)
end
]====]

--------------------------------------------------
-- 공용 파츠 도구
--------------------------------------------------
local PALETTE = {
	DarkWood = Color3.fromRGB(52, 34, 23),
	Wood = Color3.fromRGB(94, 62, 40),
	LightWood = Color3.fromRGB(131, 92, 58),
	Gold = Color3.fromRGB(198, 154, 74),
	Iron = Color3.fromRGB(70, 72, 77),
	Cursed = Color3.fromRGB(72, 132, 122),
	Floor = Color3.fromRGB(176, 146, 108),
	FloorTrim = Color3.fromRGB(129, 102, 72),
	Wall = Color3.fromRGB(214, 208, 196),
	WallTrim = Color3.fromRGB(198, 154, 74),
	Stone = Color3.fromRGB(188, 184, 176),
	SignBack = Color3.fromRGB(46, 33, 25),
	Cream = Color3.fromRGB(245, 238, 224),
}

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		part[key] = value
	end
	if parent then
		part.Parent = parent
	end
	return part
end

-- 세로로 세운 원기둥. Cylinder 는 X축이 길이 방향이라 Z로 90도 눕힌다.
local function newCylinder(props, diameter, height, position)
	local part = newPart(props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- 파츠 앞면(Front = -Z)에 글자를 붙인다. lookAt 으로 방향을 잡으면 글자가 정면을 본다.
local function addSign(part, guiName, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0 -- 게임 중 조명이 어두워져도 글씨는 읽힌다
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor or PALETTE.Cream
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.Name = "Padding"
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label

	return gui
end

--------------------------------------------------
-- 테이블 한 개 만들기
--------------------------------------------------
local function buildTable(parent, options)
	local CollectionService = game:GetService("CollectionService")

	local tableName = options.name
	local tableType = options.tableType or "Standard4"
	local seatCount = options.seatCount or 4
	local origin = options.origin

	local isSmall = seatCount <= 2
	local TABLE_TOP_RADIUS = isSmall and 3.6 or 4.6
	local TABLE_TOP_HEIGHT = 3.2
	local SEAT_RADIUS = isSmall and 5.6 or 6.6
	local SEAT_HEIGHT = 2.0

	local tableModel = Instance.new("Model")
	tableModel.Name = tableName
	tableModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	newCylinder({ Name = "Foot", Color = PALETTE.DarkWood, Parent = tableModel }, 3.4, 0.5, origin + Vector3.new(0, 0.25, 0))
	newCylinder({ Name = "Pillar", Color = PALETTE.Wood, Parent = tableModel }, 1.7, TABLE_TOP_HEIGHT - 0.5, origin + Vector3.new(0, (TABLE_TOP_HEIGHT - 0.5) / 2 + 0.3, 0))
	newCylinder({ Name = "Rim", Color = PALETTE.Gold, Material = Enum.Material.Metal, Parent = tableModel }, TABLE_TOP_RADIUS * 2 + 0.45, 0.3, origin + Vector3.new(0, TABLE_TOP_HEIGHT - 0.28, 0))

	local tableTop = newCylinder({
		Name = "TableTop",
		Color = PALETTE.LightWood,
		Material = Enum.Material.WoodPlanks,
		Parent = tableModel,
	}, TABLE_TOP_RADIUS * 2, 0.55, origin + Vector3.new(0, TABLE_TOP_HEIGHT, 0))

	tableModel.PrimaryPart = tableTop

	-- 저주받은 통 (Phase 3 에서 칼 슬롯이 붙을 자리)
	local barrel = Instance.new("Model")
	local barrelBottom = TABLE_TOP_HEIGHT + 0.28
	local barrelHeight = 4.0

	local barrelBody = newCylinder({
		Name = "Body",
		Color = PALETTE.Wood,
		Material = Enum.Material.WoodPlanks,
		Parent = barrel,
	}, 3.5, barrelHeight, origin + Vector3.new(0, barrelBottom + barrelHeight / 2, 0))

	newCylinder({ Name = "HoopLower", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + 0.9, 0))
	newCylinder({ Name = "HoopUpper", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + barrelHeight - 0.9, 0))
	newCylinder({ Name = "Lid", Color = PALETTE.DarkWood, Parent = barrel }, 3.3, 0.3, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.15, 0))

	local glow = newCylinder({
		Name = "Glow",
		Color = PALETTE.Cursed,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = barrel,
	}, 2.9, 0.12, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.34, 0))

	local glowLight = Instance.new("PointLight")
	glowLight.Color = PALETTE.Cursed
	glowLight.Brightness = 1.4
	glowLight.Range = 10
	glowLight.Parent = glow

	barrel.Name = "Barrel"
	barrel.PrimaryPart = barrelBody
	barrel.Parent = tableModel

	newPart({
		Name = "StatusAnchor",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = tableModel,
		CFrame = CFrame.new(origin + Vector3.new(0, barrelBottom + barrelHeight + 3.2, 0)),
	})

	local seatsFolder = Instance.new("Folder")
	seatsFolder.Name = "Seats"
	seatsFolder.Parent = tableModel

	for index = 1, seatCount do
		local angle = (index - 1) * (math.pi * 2 / seatCount)
		local offset = Vector3.new(math.sin(angle) * SEAT_RADIUS, SEAT_HEIGHT, math.cos(angle) * SEAT_RADIUS)
		local seatPosition = origin + offset

		-- 의자가 테이블 중앙을 바라보게 한다 → 앉은 캐릭터도 중앙을 본다
		local lookTarget = Vector3.new(origin.X, seatPosition.Y, origin.Z)
		local seatCFrame = CFrame.lookAt(seatPosition, lookTarget)

		local chair = Instance.new("Model")
		chair.Name = ("Chair_%02d"):format(index)
		chair.Parent = seatsFolder

		local seat = Instance.new("Seat")
		seat.Name = ("Seat_%02d"):format(index)
		seat.Size = Vector3.new(2.4, 0.5, 2.4)
		seat.Anchored = true
		seat.Color = PALETTE.LightWood
		seat.Material = Enum.Material.Wood
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.CFrame = seatCFrame
		seat:SetAttribute("SeatIndex", index)
		seat:SetAttribute("OccupantUserId", 0)
		seat:SetAttribute("TurnOrder", 0)
		CollectionService:AddTag(seat, "CursedBarrel_Seat")
		seat.Parent = chair

		chair.PrimaryPart = seat

		local back = newPart({
			Name = "Back",
			Size = Vector3.new(2.4, 2.4, 0.35),
			Color = PALETTE.Wood,
			Parent = chair,
		})
		back.CFrame = seatCFrame * CFrame.new(0, 1.0, 1.05)

		local crest = newPart({
			Name = "Crest",
			Size = Vector3.new(2.4, 0.25, 0.42),
			Color = PALETTE.Gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = chair,
		})
		crest.CFrame = seatCFrame * CFrame.new(0, 2.25, 1.05)

		local legHeight = SEAT_HEIGHT - 0.25
		local legPosition = seatPosition - Vector3.new(0, 0.25 + legHeight / 2, 0)
		newCylinder({ Name = "Leg", Color = PALETTE.DarkWood, Parent = chair }, 0.9, legHeight, legPosition)
		newCylinder({ Name = "LegFoot", Color = PALETTE.DarkWood, Parent = chair }, 2.0, 0.3, Vector3.new(seatPosition.X, origin.Y + 0.15, seatPosition.Z))
	end

	-- 테이블 위 랜턴. 로비에서는 장식이지만 게임이 시작돼 어두워지면 조명 역할을 한다.
	local lanternHeight = 11
	local lanternRope = newPart({
		Name = "LanternRope",
		Size = Vector3.new(0.18, 4, 0.18),
		Color = PALETTE.DarkWood,
		CanCollide = false,
		Parent = tableModel,
	})
	lanternRope.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight + 2, 0))

	local lantern = newPart({
		Name = "Lantern",
		Size = Vector3.new(1.4, 1.8, 1.4),
		Color = PALETTE.Gold,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = tableModel,
	})
	lantern.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight, 0))

	local flame = newPart({
		Name = "Flame",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Color = Color3.fromRGB(255, 196, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = tableModel,
	})
	flame.CFrame = lantern.CFrame

	local lanternLight = Instance.new("PointLight")
	lanternLight.Color = Color3.fromRGB(255, 186, 120)
	lanternLight.Brightness = 2.4
	lanternLight.Range = 32
	lanternLight.Shadows = true
	lanternLight.Parent = flame

	tableModel:SetAttribute("TableId", tableName)
	tableModel:SetAttribute("TableType", tableType)
	tableModel:SetAttribute("SeatCount", seatCount)
	tableModel:SetAttribute("SeatedCount", 0)
	tableModel:SetAttribute("MinPlayers", 1)
	tableModel:SetAttribute("State", "Waiting")
	-- Phase 2 Attribute (서버가 부팅하면서 다시 채운다. Explorer 에서 미리 보이게 만들어 둔다)
	tableModel:SetAttribute("CountdownEndsAt", 0)
	tableModel:SetAttribute("CountdownDuration", 5)
	tableModel:SetAttribute("RoundId", 0)
	tableModel:SetAttribute("ParticipantCount", 0)
	tableModel:SetAttribute("TurnCount", 0)
	tableModel:SetAttribute("TurnIndex", 0)
	tableModel:SetAttribute("CurrentTurnUserId", 0)
	tableModel:SetAttribute("CurrentTurnName", "")
	tableModel:SetAttribute("TurnEndsAt", 0)

	tableModel.Parent = parent
	CollectionService:AddTag(tableModel, "CursedBarrel_Table")

	return tableModel
end

--------------------------------------------------
-- 로비 (밝은 전시장 + 게임방)
--------------------------------------------------
local function buildLobby(parent, origin)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"

	local floor = newPart({
		Name = "Floor",
		Size = Vector3.new(160, 4, 140),
		Color = PALETTE.Floor,
		Material = Enum.Material.WoodPlanks,
		Parent = lobby,
	})
	floor.CFrame = CFrame.new(origin + Vector3.new(0, -2, 0))

	-- 테이블 구역과 전시 구역을 나누는 바닥 띠
	local divider = newPart({
		Name = "FloorStripe",
		Size = Vector3.new(160, 0.1, 3),
		Color = PALETTE.FloorTrim,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
		Parent = lobby,
	})
	divider.CFrame = CFrame.new(origin + Vector3.new(0, 0.05, -48))

	local function wall(name, size, position)
		local part = newPart({
			Name = name,
			Size = size,
			Color = PALETTE.Wall,
			Material = Enum.Material.Concrete,
			Parent = lobby,
		})
		part.CFrame = CFrame.new(origin + position)
		return part
	end

	local function trim(name, size, position)
		local part = newPart({
			Name = name,
			Size = size,
			Color = PALETTE.WallTrim,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = lobby,
		})
		part.CFrame = CFrame.new(origin + position)
		return part
	end

	wall("Wall_North", Vector3.new(164, 16, 4), Vector3.new(0, 8, -72))
	wall("Wall_South", Vector3.new(164, 16, 4), Vector3.new(0, 8, 72))
	wall("Wall_West", Vector3.new(4, 16, 148), Vector3.new(-82, 8, 0))
	wall("Wall_East", Vector3.new(4, 16, 148), Vector3.new(82, 8, 0))

	trim("Trim_North", Vector3.new(164, 0.9, 4.4), Vector3.new(0, 16.4, -72))
	trim("Trim_South", Vector3.new(164, 0.9, 4.4), Vector3.new(0, 16.4, 72))
	trim("Trim_West", Vector3.new(4.4, 0.9, 148), Vector3.new(-82, 16.4, 0))
	trim("Trim_East", Vector3.new(4.4, 0.9, 148), Vector3.new(82, 16.4, 0))

	--------------------------------------------------
	-- 스킨/디자인 전시 구역 (Phase 4 에서 상점으로 연결할 자리)
	--------------------------------------------------
	local shop = Instance.new("Folder")
	shop.Name = "ShopDisplay"
	shop.Parent = lobby

	local stage = newPart({
		Name = "Stage",
		Size = Vector3.new(80, 3, 16),
		Color = PALETTE.Stone,
		Material = Enum.Material.Marble,
		Parent = shop,
	})
	stage.CFrame = CFrame.new(origin + Vector3.new(0, 1.5, -60))

	for index = 1, 5 do
		local x = -30 + (index - 1) * 15
		local base = origin + Vector3.new(x, 3, -60)

		newCylinder({ Name = ("Pedestal_%02d"):format(index), Color = PALETTE.Stone, Material = Enum.Material.Marble, Parent = shop }, 6, 2.4, base + Vector3.new(0, 1.2, 0))
		newCylinder({ Name = ("PedestalTop_%02d"):format(index), Color = PALETTE.Gold, Material = Enum.Material.Metal, Parent = shop }, 6.6, 0.4, base + Vector3.new(0, 2.6, 0))

		-- 전시할 의자/스킨 모델을 여기에 올리면 된다. 위치 기준점만 남겨 둔다.
		local anchor = newPart({
			Name = ("DisplayAnchor_%02d"):format(index),
			Size = Vector3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = shop,
		})
		anchor.CFrame = CFrame.new(base + Vector3.new(0, 3.3, 0))
	end

	local shopSign = newPart({
		Name = "ShopSign",
		Size = Vector3.new(44, 9, 1),
		Color = PALETTE.SignBack,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = shop,
	})
	shopSign.CFrame = CFrame.lookAt(origin + Vector3.new(0, 12, -69), origin + Vector3.new(0, 12, 0))
	addSign(shopSign, "ShopLabel", "의자 스킨 전시장\n(구매 기능은 준비 중)", PALETTE.Gold)

	--------------------------------------------------
	-- 안내판 + 스폰
	--------------------------------------------------
	local howToPlay = newPart({
		Name = "HowToPlay",
		Size = Vector3.new(26, 10, 1),
		Color = PALETTE.SignBack,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = lobby,
	})
	howToPlay.CFrame = CFrame.lookAt(origin + Vector3.new(-40, 8, 68), origin + Vector3.new(-40, 8, 0))
	addSign(
		howToPlay,
		"Instructions",
		"저주받은 통 · PHASE 2\n의자 가까이에서 E (모바일은 탭)\n5초 뒤 게임이 시작됩니다\n게임이 시작되면 조명이 어두워져요",
		PALETTE.Cream
	)

	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "LobbySpawn"
	spawnPart.Size = Vector3.new(16, 1, 16)
	spawnPart.Anchored = true
	spawnPart.CanCollide = true
	spawnPart.Neutral = true
	spawnPart.AllowTeamChangeOnTouch = false
	spawnPart.Color = PALETTE.Gold
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Transparency = 0.6
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.BottomSurface = Enum.SurfaceType.Smooth
	spawnPart.CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 52))
	spawnPart.Parent = lobby

	lobby.Parent = parent
	return lobby
end

--------------------------------------------------
-- 라이팅 (로비 = 밝음. 어두워지는 연출은 게임 중에만 클라이언트가 적용한다)
-- 값은 GameConfig.Lighting.Lobby 와 같게 맞춰져 있다.
--------------------------------------------------
local function applyLighting(setLighting, replace)
	local Lighting = game:GetService("Lighting")

	setLighting("Ambient", Color3.fromRGB(122, 120, 116))
	setLighting("OutdoorAmbient", Color3.fromRGB(154, 158, 168))
	setLighting("Brightness", 2.8)
	setLighting("ClockTime", 14.3)
	setLighting("GeographicLatitude", 12)
	setLighting("ExposureCompensation", 0)
	setLighting("EnvironmentDiffuseScale", 0.6)
	setLighting("EnvironmentSpecularScale", 0.5)
	setLighting("GlobalShadows", true)
	setLighting("FogColor", Color3.fromRGB(206, 214, 224))
	setLighting("FogEnd", 100000)

	local function ensure(className, name)
		local instance = Instance.new(className)
		instance.Name = name
		replace(Lighting, name, instance)
		return instance
	end

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(226, 226, 220)
	atmosphere.Decay = Color3.fromRGB(150, 165, 185)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.3
	bloom.Size = 22
	bloom.Threshold = 1.3

	local colorCorrection = ensure("ColorCorrectionEffect", "ColorCorrection")
	colorCorrection.Brightness = 0.01
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.1
	colorCorrection.TintColor = Color3.fromRGB(255, 252, 246)

	print("[CursedBarrel] 로비 조명(밝음) 설정 완료")
end

--------------------------------------------------
-- 설치
--------------------------------------------------
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local Storage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Editor = game:GetService("ScriptEditorService")
local History = game:GetService("ChangeHistoryService")

local stage = Instance.new("Folder")
stage.Name = "CursedBarrel_Staging"
stage.Parent = Storage

local created, replacements, lightingBefore = {}, {}, {}
local backup = Instance.new("Folder")
backup.Name = "CursedBarrel_Backup_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. game:GetService("HttpService"):GenerateGUID(false):sub(1, 8)

local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), existing:GetFullName() .. " must be a Folder; nothing at this path was overwritten.")
		return existing
	end
	local result = Instance.new("Folder")
	result.Name = name
	table.insert(created, result)
	result.Parent = parent
	return result
end

local function disableScriptsIn(root, record)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, item in ipairs(all) do
		if item:IsA("BaseScript") then
			record.enabled[item] = item.Enabled
			item:SetAttribute("CB_BackupWasEnabled", item.Enabled)
			item.Enabled = false
		end
	end
end

local function replace(parent, name, fresh)
	local old = parent:FindFirstChild(name)
	local record = { parent = parent, old = old, fresh = fresh, enabled = {} }
	table.insert(replacements, record)
	if old then
		local slot = Instance.new("Folder")
		slot.Name = ("%02d_%s"):format(#replacements, name)
		slot:SetAttribute("OriginalParent", parent:GetFullName())
		slot.Parent = backup
		disableScriptsIn(old, record)
		old.Parent = slot
	end
	fresh.Name = name
	fresh.Parent = parent
end

-- 교체할 새 항목 없이 기존 항목만 백업으로 옮긴다. (옛 장식/스폰 정리용)
local function stash(instance)
	if not instance or not instance.Parent then
		return
	end
	local record = { parent = instance.Parent, old = instance, fresh = nil, enabled = {} }
	table.insert(replacements, record)
	local slot = Instance.new("Folder")
	slot.Name = ("%02d_%s"):format(#replacements, instance.Name)
	slot:SetAttribute("OriginalParent", instance.Parent:GetFullName())
	slot.Parent = backup
	disableScriptsIn(instance, record)
	instance.Parent = slot
end

local function setLighting(property, value)
	if lightingBefore[property] == nil then
		lightingBefore[property] = Lighting[property]
		backup:SetAttribute("Lighting_" .. property, Lighting[property])
	end
	Lighting[property] = value
end

local function preflightPath(root, path)
	local parent = root
	for _, name in ipairs(path) do
		local found = parent:FindFirstChild(name)
		if not found then return end
		assert(found:IsA("Folder"), found:GetFullName() .. " must be a Folder. Installation stopped.")
		parent = found
	end
end

local ok, err = xpcall(function()
	preflightPath(RS, {"CursedBarrel", "Shared"})
	preflightPath(SS, {"CursedBarrel", "Services"})
	preflightPath(SP, {"Controllers"})
	preflightPath(workspace, {"GameTables"})

	local definitions = {
		{"GameConfig", "ModuleScript"}, {"TableConfig", "ModuleScript"},
		{"Utility", "ModuleScript"}, {"GameTable", "ModuleScript"},
		{"TableService", "ModuleScript"}, {"RoundService", "ModuleScript"},
		{"Main", "Script"},
		{"TableController", "LocalScript"}, {"LightingController", "LocalScript"},
	}

	-- 모든 소스를 먼저 준비하고 확인한 후 실제 경로에 설치합니다.
	local scripts = {}
	for _, definition in ipairs(definitions) do
		local name, className = definition[1], definition[2]
		assert(SOURCES[name], "Missing source: " .. name)
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = stage
		Editor:UpdateSourceAsync(instance, function() return SOURCES[name] end)
		assert(Editor:GetEditorSource(instance) == SOURCES[name], "Source verification failed: " .. name)
		scripts[name] = instance
	end

	-- 테이블과 로비를 미리 만들어 검사한다.
	local builtTables, lobby = {}, nil
	if REBUILD_MAP then
		for _, layout in ipairs(TABLE_LAYOUT) do
			local model = buildTable(stage, {
				name = layout.name,
				tableType = layout.tableType,
				seatCount = layout.seatCount,
				origin = LOBBY_ORIGIN + layout.offset,
			})

			local seatCount = 0
			for _, descendant in ipairs(model.Seats:GetDescendants()) do
				if descendant:IsA("Seat") then
					seatCount += 1
					assert(descendant.Anchored and descendant:GetAttribute("SeatIndex"), "Invalid seat in " .. layout.name)
				end
			end
			assert(seatCount == layout.seatCount, "Seat count mismatch: " .. layout.name)
			assert(model.PrimaryPart and model:FindFirstChild("StatusAnchor"), "Table validation failed: " .. layout.name)

			table.insert(builtTables, model)
		end

		lobby = buildLobby(stage, LOBBY_ORIGIN)
		assert(lobby:FindFirstChild("Floor") and lobby:FindFirstChildWhichIsA("SpawnLocation"), "Lobby validation failed")
	end

	-- 백업은 서버 전용 저장소에 보관됩니다. 기존 소스의 편집 중 버퍼도 저장합니다.
	backup.Parent = Storage

	local shared = folder(folder(RS, "CursedBarrel"), "Shared")
	local serverRoot = folder(SS, "CursedBarrel")
	local services = folder(serverRoot, "Services")
	local controllers = folder(SP, "Controllers")
	local gameTables = folder(workspace, "GameTables")

	local destinations = {
		GameConfig = shared, TableConfig = shared, Utility = shared,
		GameTable = services, TableService = services, RoundService = services,
		Main = serverRoot,
		TableController = controllers, LightingController = controllers,
	}

	for _, definition in ipairs(definitions) do
		local name = definition[1]
		local old = destinations[name]:FindFirstChild(name)
		if old and old:IsA("LuaSourceContainer") then
			local draft = Instance.new("StringValue")
			draft.Name = name .. "_EditorSource"
			draft.Value = Editor:GetEditorSource(old)
			draft:SetAttribute("OriginalPath", old:GetFullName())
			draft.Parent = backup
		end
		replace(destinations[name], name, scripts[name])
	end

	if REBUILD_MAP then
		for _, model in ipairs(builtTables) do
			replace(gameTables, model.Name, model)
		end
		replace(workspace, "Lobby", lobby)

		-- Phase 1 때 놓였던 바닥/안내판은 새 로비와 겹치므로 백업으로 옮긴다.
		stash(workspace:FindFirstChild("TavernFloor"))
		stash(workspace:FindFirstChild("HowToPlay"))

		if REPLACE_SPAWN then
			-- 스폰이 여러 개면 플레이어가 아무 곳에나 나타난다. 로비 스폰만 남긴다.
			for _, descendant in ipairs(workspace:GetDescendants()) do
				-- 목록은 미리 찍어둔 사본이라, 이미 백업으로 옮겨진 것은 건너뛴다.
				if descendant:IsA("SpawnLocation")
					and descendant:IsDescendantOf(workspace)
					and not descendant:IsDescendantOf(lobby)
				then
					stash(descendant)
				end
			end
		end
	end

	if APPLY_LIGHTING then
		applyLighting(setLighting, replace)
	end

	for _, definition in ipairs(definitions) do
		local name = definition[1]
		assert(destinations[name]:FindFirstChild(name) == scripts[name], "Install verification failed: " .. name)
	end

	local CollectionService = game:GetService("CollectionService")
	local taggedCount = 0
	for _, model in ipairs(CollectionService:GetTagged("CursedBarrel_Table")) do
		if model:IsDescendantOf(workspace) then
			taggedCount += 1
		end
	end
	if REBUILD_MAP then
		assert(taggedCount >= #TABLE_LAYOUT, "Missing table tags")
	end

	stage:Destroy()
	pcall(function() History:SetWaypoint("CursedBarrel Phase 2 installed") end)
	pcall(function()
		if REBUILD_MAP then
			game:GetService("Selection"):Set({ gameTables })
		end
	end)

	print(("[CursedBarrel] 설치 완료 · 스크립트 %d개 / 테이블 %d개 / 조명 %s")
		:format(#definitions, REBUILD_MAP and #TABLE_LAYOUT or 0, APPLY_LIGHTING and "밝은 로비" or "변경 없음"))
	print("[CursedBarrel] 점검 1 · 의자 근처 E → 5초 카운트다운 → 게임 시작 (혼자서도 됩니다)")
	print("[CursedBarrel] 점검 2 · 카운트다운 중 점프로 일어나면 즉시 취소, 다시 앉으면 새 카운트다운")
	print("[CursedBarrel] 점검 3 · 게임이 시작되면 다른 빈 의자에는 앉을 수 없고 내 화면만 어두워집니다")
	print("[CursedBarrel] 점검 4 · 테이블마다 따로 진행됩니다 (Table_A ~ Table_F)")
	print("[CursedBarrel] 2명 이상 모여야 시작하게 하려면 Shared/TableConfig 의 MinPlayers 를 2로 바꾸세요.")
	print("[CursedBarrel] 기존 항목 백업: " .. backup:GetFullName())
end, debug.traceback)

if not ok then
	-- 설치 실패 시 새 항목을 제거하고 이동했던 원본과 조명 값을 되돌립니다.
	for index = #replacements, 1, -1 do
		local record = replacements[index]
		pcall(function()
			if record.fresh then
				record.fresh:Destroy()
			end
			if record.old then
				record.old.Parent = record.parent
				for item, enabled in pairs(record.enabled) do
					item.Enabled = enabled
					item:SetAttribute("CB_BackupWasEnabled", nil)
				end
			end
		end)
	end
	for property, value in pairs(lightingBefore) do pcall(function() Lighting[property] = value end) end
	for index = #created, 1, -1 do pcall(function() created[index]:Destroy() end) end
	stage:Destroy()
	-- 복구에 실패한 원본이 있을 가능성에 대비해 백업은 남깁니다.
	if backup.Parent == nil then backup.Parent = Storage end
	error("[CursedBarrel] 설치 실패. 기존 항목 복구를 시도했습니다. 오류: " .. tostring(err), 0)
end
