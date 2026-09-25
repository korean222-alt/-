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

-- 배열에서 하나를 무작위로 고른다. 비어 있으면 nil.
-- (Phase 3: 제한 시간이 끝났을 때 서버가 대신 고르는 자리)
function Utility.pickRandom(array, random)
	local count = #array
	if count == 0 then
		return nil
	end
	local index = random and random:NextInteger(1, count) or math.random(1, count)
	return array[index], index
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

-- 장식 파트를 "부딪히지도 만져지지도 검사되지도 않는" 상태로 만든다.
-- Phase 6 : 장식이 늘어나면 이걸 안 한 파트 하나가 모바일 프레임을 갉아먹는다.
function Utility.makeDecor(part, castShadow)
	if not part or not part:IsA("BasePart") then
		return part
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = castShadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- 모델 안의 모든 BasePart 에 같은 처리를 한다.
function Utility.forEachPart(instance, handler)
	if not instance then
		return
	end
	if instance:IsA("BasePart") then
		handler(instance)
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			handler(descendant)
		end
	end
end

-- 오늘 날짜(UTC)를 "2026-09-22" 같은 문자열로. 일일 퀘스트 갱신 기준.
function Utility.today()
	return os.date("!%Y-%m-%d")
end

-- 큰 수를 읽기 좋게. 1234567 → "1,234,567"
function Utility.comma(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

return Utility