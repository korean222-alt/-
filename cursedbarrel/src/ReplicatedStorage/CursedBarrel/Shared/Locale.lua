--[[
	Locale  (Phase 13)
	화면 글자를 영어로 바꾼다. 게임 코드는 한국어로 쓰고, 영어는 LocaleData(자동 생성)에 모아 둔다.

	Locale.translate(text) 순서
	  1. 한글이 없으면 그대로
	  2. 통째로 같은 문장이 사전에 있으면 그 영어
	  3. 숫자 · 이름이 끼워진 문장("%d 코인" 같은 틀)이면 틀에 맞춰 영어로. 끼워진 이름도 다시 번역한다
	  4. 그래도 남으면 사전에 있는 조각(2글자 이상)을 긴 것부터 바꾼다 ("청해룡" + "의 송곳니" → "Tide Dragon's Fang")

	Locale.language(player) : "en" 또는 "ko". 설정의 언어(Auto 면 Roblox 계정 언어가 한국어일 때만 한국어).
]]

local DATA = require(script.Parent.LocaleData)

local Locale = {}

local HANGUL = "[\234-\237]" -- UTF-8 에서 한글 음절(U+AC00~U+D7A3)이 시작하는 바이트
local SPEC = "%%[%-+#0]*%d*%.?%d*[dsf]"

local exact = {}
local templates = {}
local fragments = {}

local function hasHangul(text)
	return string.find(text, HANGUL) ~= nil
end

local function trim(text)
	return (string.gsub(text, "^%s+", ""):gsub("%s+$", ""))
end

-- 한국어 틀 → Lua 패턴
local function toPattern(template)
	local out = { "^" }
	local index = 1
	local length = #template
	while index <= length do
		local char = string.sub(template, index, index)
		if char == "%" then
			if string.sub(template, index + 1, index + 1) == "%" then
				table.insert(out, "%%")
				index += 2
			else
				local s, e = string.find(template, SPEC, index)
				if s == index then
					local spec = string.sub(template, s, e)
					local kind = string.sub(spec, -1)
					if kind == "d" then
						table.insert(out, "%s*(%-?%d+)")
					elseif kind == "f" then
						table.insert(out, "(%-?[%d%.]+)")
					else
						table.insert(out, "(.-)")
					end
					index = e + 1
				else
					table.insert(out, "%%")
					index += 1
				end
			end
		elseif string.find(char, "[%^%$%(%)%.%[%]%*%+%-%?]") then
			table.insert(out, "%" .. char)
			index += 1
		else
			table.insert(out, char)
			index += 1
		end
	end
	table.insert(out, "$")
	return table.concat(out)
end

-- 앞뒤의 빈칸과 "·" 를 떼어 낸 알맹이 ("  ·  해적 %d마리" → "해적 %d마리")
local DOT = "\194\183"
local function core(text)
	local out = text
	repeat
		local before = out
		out = string.gsub(out, "^%s+", ""):gsub("%s+$", "")
		if string.sub(out, 1, 2) == DOT then
			out = string.sub(out, 3)
		end
		if string.sub(out, -2) == DOT then
			out = string.sub(out, 1, -3)
		end
	until out == before
	return out
end

local function addTemplate(ko, en)
	local literal = string.gsub(string.gsub(ko, "%%%%", ""), SPEC, "")
	if hasHangul(literal) then
		table.insert(templates, { pattern = toPattern(ko), en = en, weight = #literal })
	end
end

for ko, en in pairs(DATA) do
	exact[ko] = en
	if string.find(ko, SPEC) then
		addTemplate(ko, en)
		local koCore = core(ko)
		if koCore ~= ko and not DATA[koCore] then
			addTemplate(koCore, core(en))
		end
	else
		local koCore = core(ko)
		if koCore ~= ko and hasHangul(koCore) then
			exact[koCore] = exact[koCore] or core(en)
		end
		local key = trim(ko)
		-- 한 글자 조각("칼" "통" "나")은 다른 낱말 속에서 잘못 바뀌기 쉬워 통째로 같을 때만 쓴다
		if hasHangul(key) and #key > 3 then
			table.insert(fragments, { ko = key, en = trim(en) })
		end
		if key ~= ko then
			exact[key] = exact[key] or trim(en)
		end
	end
end
table.sort(templates, function(a, b)
	return a.weight > b.weight
end)
table.sort(fragments, function(a, b)
	if #a.ko ~= #b.ko then
		return #a.ko > #b.ko
	end
	return a.ko < b.ko
end)

local translate

-- 영어 틀에 잡은 값을 차례로 넣는다 (%d · %.1f · %s 모두 글자로 넣는다)
local function fill(template, captures)
	local index = 0
	-- "%%" 는 잠시 \1 로 숨겼다가 마지막에 "%" 로 되돌린다
	local result = string.gsub(template, "%%%%", "\1"):gsub(SPEC, function()
		index += 1
		local value = captures[index] or ""
		if hasHangul(value) then
			value = translate(value, true)
		end
		return value
	end)
	return (string.gsub(result, "\1", "%%"))
end

local function isWordByte(byte)
	return byte ~= nil and (byte >= 48 and byte <= 57 or byte >= 65 and byte <= 90 or byte >= 97 and byte <= 122 or byte >= 128)
end

local function replaceFragments(text)
	for _, fragment in ipairs(fragments) do
		local start = 1
		while true do
			local s, e = string.find(text, fragment.ko, start, true)
			if not s then
				break
			end
			local en = fragment.en
			if en ~= "" and isWordByte(string.byte(text, s - 1)) and isWordByte(string.byte(en, 1)) then
				en = " " .. en
			end
			if en ~= "" and isWordByte(string.byte(text, e + 1)) and isWordByte(string.byte(en, -1)) then
				en = en .. " "
			end
			text = string.sub(text, 1, s - 1) .. en .. string.sub(text, e + 1)
			start = s + #en
		end
		if not hasHangul(text) then
			break
		end
	end
	return text
end

-- 사전(통째 · 틀)에서만 찾는다. 없으면 nil
local function strict(text)
	local found = exact[text] or exact[trim(text)]
	if found then
		return found
	end
	for _, template in ipairs(templates) do
		local captures = { string.match(text, template.pattern) }
		if #captures > 0 then
			return fill(template.en, captures)
		end
	end
	return nil
end

-- "A · B · C" 처럼 이어 붙인 글자는 조각마다 번역한다 (빈칸은 그대로 둔다)
-- 사전에 "A · B" 가 통째로 있으면 그 덩어리를 먼저 쓴다 (가장 긴 덩어리부터)
local function translateSegments(text)
	if not string.find(text, DOT, 1, true) then
		return nil
	end
	local pieces = {}
	local start = 1
	while true do
		local s, e = string.find(text, DOT, start, true)
		table.insert(pieces, s and string.sub(text, start, s - 1) or string.sub(text, start))
		if not s then
			break
		end
		start = e + 1
	end
	local out = {}
	local i = 1
	while i <= #pieces do
		local done = false
		for j = #pieces, i + 1, -1 do
			local chunk = table.concat(pieces, DOT, i, j)
			local lead, body, tail = string.match(chunk, "^(%s*)(.-)(%s*)$")
			local found = hasHangul(body) and strict(body)
			if found then
				table.insert(out, lead .. found .. tail)
				i = j + 1
				done = true
				break
			end
		end
		if not done then
			local lead, body, tail = string.match(pieces[i], "^(%s*)(.-)(%s*)$")
			table.insert(out, lead .. (hasHangul(body) and translate(body, true) or body) .. tail)
			i += 1
		end
	end
	return table.concat(out, DOT)
end

local cache = {}
local cacheSize = 0

translate = function(text, nested)
	if typeof(text) ~= "string" or text == "" or not hasHangul(text) then
		return text
	end
	local hit = cache[text]
	if hit then
		return hit
	end
	local result = strict(text)
	if not result then
		result = translateSegments(text)
	end
	if not result then
		-- 줄마다 따로 (여러 줄 글자는 줄 단위로 만들어진 경우가 많다)
		if string.find(text, "\n") and not nested then
			local lines = {}
			for line in string.gmatch(text .. "\n", "(.-)\n") do
				table.insert(lines, translate(line, true))
			end
			result = table.concat(lines, "\n")
		else
			result = replaceFragments(text)
		end
	end
	if cacheSize > 4000 then
		table.clear(cache)
		cacheSize = 0
	end
	cache[text] = result
	cacheSize += 1
	return result
end

Locale.translate = translate
Locale.hasHangul = hasHangul

function Locale.language(player)
	local chosen = player and player:GetAttribute("Setting_language")
	if chosen == "ko" or chosen == "en" then
		return chosen
	end
	local localeId = player and player.LocaleId or "ko-kr"
	return string.sub(string.lower(localeId), 1, 2) == "ko" and "ko" or "en"
end

return Locale
