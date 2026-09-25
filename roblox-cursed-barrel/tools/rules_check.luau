-- Phase 21 규칙 검사 (Lune) : 잡기 창 곡선 · 잭팟 확률 · 심장 박동 빠르기를 실제 게임 코드로 돌려 본다.
--   lune run tools/rules_check.luau output/CursedBarrel_Phase21_Music.rbxl
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name)
end)
roblox.implementMethod("RunService", "IsStudio", function()
	return false
end)
local RS = game:GetService("ReplicatedStorage")
local shared = RS.CursedBarrel.Shared

local failures = 0
local function check(ok, what)
	print((ok and "ok    " or "FAIL  ") .. what)
	if not ok then
		failures += 1
	end
end

-- 진짜 난수 (Roblox Random 흉내)
local function newRandom(seed)
	local state = seed or 1
	local function nextFloat()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_) return nextFloat() end,
		NextInteger = function(_, a, b) return a + math.floor(nextFloat() * (b - a + 1)) end,
	}
end

local cache = {}
local function load(inst)
	if cache[inst] then
		return cache[inst]
	end
	local env = setmetatable({
		script = inst, game = game, require = load,
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
		UDim2 = roblox.UDim2, UDim = roblox.UDim, NumberSequence = roblox.NumberSequence, ColorSequence = roblox.ColorSequence,
		NumberRange = roblox.NumberRange, Random = { new = function() return newRandom(7) end }, typeof = typeof,
		warn = function() end, print = function() end, workspace = game:GetService("Workspace"),
	}, { __index = _G })
	local result = luau.load(inst.Source, { debugName = inst.Name, environment = env })()
	cache[inst] = result
	return result
end

local GameConfig = load(shared.GameConfig)

--------------------------------------------------
-- 1. 잡기 창 : 어려운 경지(0.40초) 부터는 0.02초씩
--------------------------------------------------
local CATCH = GameConfig.Catch
check(CATCH.MaxPerPlayer == 16, "분노한 해적은 16번 잡은 뒤")
local line, hardSteps, prevHard = {}, 0, nil
local okSteps = true
for personal = 0, CATCH.MaxPerPlayer - 1 do
	-- 2인 판 : 두 사람이 번갈아 잡는다고 치면 테이블 전체 잡은 수는 personal * 2
	local window, hard = GameConfig.catchWindow(personal * 2, 2, 8, personal, hardSteps)
	table.insert(line, ("%.2f%s"):format(window, hard and "*" or ""))
	if hard then
		if prevHard and math.abs((prevHard - window) - CATCH.HardStep) > 1e-6 and window > CATCH.MinWindow + 1e-6 then
			okSteps = false
		end
		prevHard = window
		hardSteps += 1
	end
end
print("  2인 판 창 길이 (*=어려운 경지) : " .. table.concat(line, " "))
check(okSteps, "어려운 경지에서는 한 번에 정확히 0.02초씩 좁아진다")
check(prevHard ~= nil and prevHard >= CATCH.MinWindow - 1e-6, "0.20초 아래로는 안 내려간다")
local first = GameConfig.catchWindow(0, 4, 16, 0, 0)
check(math.abs(first - CATCH.BaseWindow) < 1e-6, ("첫 해적 창은 그대로 %.2f초"):format(first))

--------------------------------------------------
-- 2. 잭팟 : 실제 Round:_rollJackpot 코드를 떼어 돌린다
--------------------------------------------------
local source = game:GetService("ServerScriptService").CursedBarrel.Services.RoundService.Source
local a = string.find(source, "function Round:_rollJackpot", 1, true)
local b = string.find(source, "\nend\n", a, true)
local body = string.sub(source, a, b + 4)
local fired = {}
local chunk = "local Round = {}\n" .. body .. "\nreturn Round"
local Round = luau.load(chunk, { environment = setmetatable({
	GameConfig = GameConfig, POT = GameConfig.Pot, TABLE_ATTR = GameConfig.TableAttributes,
	presentation = { FireAllClients = function(_, kind, _, data) table.insert(fired, data) end },
}, { __index = _G }) })()

local TRIALS = 200000
for _, case in ipairs({ { stage = 1, big = 0.01 }, { stage = 2, big = 0.03 }, { stage = 3, big = 0.05 } }) do
	local big, small = 0, 0
	for t = 1, TRIALS do
		local stageValue = case.stage
		local self = setmetatable({
			gameTable = { tableId = "T", model = { GetAttribute = function() return stageValue end } },
			random = nil, pot = 0, practice = false,
			_set = function() end,
		}, { __index = Round })
		self.random = newRandom(t * 7919)
		table.clear(fired)
		-- 한 라운드에 안전한 자리 6번
		for _ = 1, 6 do
			self:_rollJackpot({ UserId = 1, DisplayName = "p", Name = "p" })
		end
		for _, data in ipairs(fired) do
			if data.tier == "big" then big += 1 else small += 1 end
		end
	end
	local bigRate, smallRate = big / TRIALS, small / TRIALS
	local smallExpected = (1 - case.big) * 0.10
	print(("  %d라운드 : 큰 잭팟 %.2f%% (목표 %.0f%%) · 잭팟 %.2f%% (목표 %.1f%%)"):format(case.stage, bigRate * 100, case.big * 100, smallRate * 100, smallExpected * 100))
	check(math.abs(bigRate - case.big) < 0.004 and math.abs(smallRate - smallExpected) < 0.006, ("%d라운드 잭팟 확률이 설정과 맞다"):format(case.stage))
end
-- 금액
do
	local self = setmetatable({
		gameTable = { tableId = "T", model = { GetAttribute = function() return 3 end } },
		random = { NextNumber = function() return 0 end, NextInteger = function(_, x) return x end }, pot = 100, practice = false, _set = function() end,
	}, { __index = Round })
	table.clear(fired)
	self:_rollJackpot({ UserId = 1, DisplayName = "p", Name = "p" })
	check(fired[1] and fired[1].amount == 10000 and self.pot == 10100, "큰 잭팟은 현상금에 정확히 10,000 을 더한다")
	self.practice = true
	self.jackpotStage = nil
	table.clear(fired)
	self:_rollJackpot({ UserId = 1, DisplayName = "p", Name = "p" })
	check(fired[1] and fired[1].amount == math.floor(10000 * GameConfig.Bots.RewardScale), "AI 연습 판은 RewardScale 만큼만")
end

--------------------------------------------------
-- 3. 심장 박동 : 라운드마다 빨라진다
--------------------------------------------------
local phase4 = game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.Phase4Controller.Source
local ha = string.find(phase4, "local function heartRate", 1, true)
local hb = string.find(phase4, "\nend\n", ha, true)
local heartRate = luau.load(string.sub(phase4, ha, hb + 4):gsub("^local function heartRate", "return function") , {})()
local rates = {}
for stage = 1, 5 do
	table.insert(rates, heartRate(stage, 5, 0))
end
print("  6인 판 라운드별 박동(분당) : " .. table.concat(rates, " → ") .. "  · 위험 최대 " .. heartRate(5, 5, 1))
local rising = true
for i = 2, #rates do
	rising = rising and rates[i] > rates[i - 1]
end
check(rising, "라운드가 올라갈수록 심장이 빨리 뛴다")
check(heartRate(5, 5, 1) <= 156, "아무리 위험해도 분당 156 이하")

--------------------------------------------------
-- 4. 테이블 : 스폰에서 가까운 줄부터 2 · 3 · 4인
--------------------------------------------------
local layout = load(shared.ShipLayout)
local TableConfig = load(shared.TableConfig)
local rows = {}
for name, pos in pairs(layout.Tables) do
	local typeName = GameConfig.TableTypeByName[name]
	table.insert(rows, { name = name, z = pos[2], seats = TableConfig.get(typeName).SeatCount, upper = pos[3] ~= nil })
end
table.sort(rows, function(x, y) return x.z > y.z end)
local order, lastSeats, sorted = {}, 0, true
for _, r in ipairs(rows) do
	table.insert(order, ("%s(z%d)=%d인"):format(r.name, r.z, r.seats))
	if not r.upper then
		sorted = sorted and r.seats >= lastSeats
		lastSeats = r.seats
	end
end
print("  " .. table.concat(order, "  "))
check(sorted, "주 갑판 테이블은 스폰에서 멀어질수록 인원이 같거나 많다")

print(("\n%d failure(s)"):format(failures))
if failures > 0 then
	process.exit(1)
end
