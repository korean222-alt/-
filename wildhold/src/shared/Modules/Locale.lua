-- 번역. 문장은 Shared/Locale/<언어>.lua 에 키 → 문장으로 있다 (en 이 기준, 없는 키는 en → 키 그대로).
--  서버는 언어를 모른다: 문장 대신 "메시지" 를 보낸다 → 각 플레이어 화면에서 그 사람 언어로 바꾼다.
--    L.M("build.placed", {name = L.M("defense.Wall")})  →  {k = "build.placed", a = {name = {k = "defense.Wall"}}}
--    L.C(a, b, c)  →  여러 조각을 이어 붙인 메시지.  문자열·숫자는 그대로 보인다 (펫 이름 등)
--  문장 속 {name} 은 a.name 으로 바뀐다 (값이 메시지면 그것도 번역).
--  프롬프트·간판처럼 서버가 만든 글자: L.tag(obj, "Text", msg) → 속성에 저장, 클라이언트 L.watch 가 번역해서 채운다.
local RS = game:GetService("ReplicatedStorage")

local L = {}
L.Languages = {"en", "ko", "es", "pt"}
L.Names = {en = "English", ko = "한국어", es = "Español", pt = "Português"}
L.lang = "en"

local folder = RS:WaitForChild("Shared"):WaitForChild("Locale")
local tables = {}
for _, code in ipairs(L.Languages) do tables[code] = require(folder:WaitForChild(code)) end
L.Tables = tables

-- "ko-kr" · "pt-br" · "es-mx" → 지원하는 언어 코드 (없으면 en)
function L.pick(localeId)
	local code = string.lower(tostring(localeId or "")):sub(1, 2)
	return tables[code] and code or "en"
end

-- 플레이어 언어 (서버에서 Kick 글자처럼 직접 글자를 만들 때): 설정에서 고른 언어(속성 Lang) → Roblox 계정 언어
function L.of(player)
	local chosen = player:GetAttribute("Lang")
	if type(chosen) == "string" and tables[chosen] then return chosen end
	local ok, id = pcall(function() return player.LocaleId end)
	return L.pick(ok and id or "")
end

function L.M(key, args) return {k = key, a = args} end
function L.C(...) return {c = {...}} end

local text
local function fill(s, args, lang)
	if not args then return s end
	return (string.gsub(s, "{(%w+)}", function(name)
		local v = args[name]
		if v == nil then v = args[tonumber(name)] end
		if v == nil then return "{" .. name .. "}" end
		return text(v, lang)
	end))
end

-- 메시지(또는 문자열·숫자) → 글자
text = function(v, lang)
	lang = lang or L.lang
	local kind = type(v)
	if kind == "string" then return v end
	if kind == "number" then return (v == math.floor(v) and string.format("%d", v)) or tostring(v) end
	if kind ~= "table" then return v == nil and "" or tostring(v) end
	if v.c then
		local out = {}
		for i, part in ipairs(v.c) do out[i] = text(part, lang) end
		return table.concat(out)
	end
	if v.k then
		local s = (tables[lang] and tables[lang][v.k]) or tables.en[v.k] or v.k
		return fill(s, v.a, lang)
	end
	return ""
end
L.text = text

-- 키 바로 번역 (클라이언트 자기 문장)
function L.t(key, args, lang)
	lang = lang or L.lang
	local s = (tables[lang] and tables[lang][key]) or tables.en[key] or key
	return fill(s, args, lang)
end

function L.has(key) return tables.en[key] ~= nil end

-- ===================================================================== 속성에 넣을 수 있게 메시지 ↔ 문자열
local function enc(v)
	local kind = type(v)
	if kind == "number" then return "n" .. tostring(v) .. ";" end
	if kind == "string" then return "s" .. #v .. ":" .. v end
	if kind == "boolean" then return v and "T" or "F" end
	if kind == "table" then
		local keys = {}
		for k in pairs(v) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		local out = {"{"}
		for _, k in ipairs(keys) do
			local value = v[k]
			if value == nil then value = v[tonumber(k)] end
			table.insert(out, enc(k) .. enc(value))
		end
		table.insert(out, "}")
		return table.concat(out)
	end
	return "F"
end
L.encode = enc

function L.decode(s)
	if type(s) ~= "string" or s == "" then return nil end
	local i = 1
	local function read()
		local tag = s:sub(i, i)
		i = i + 1
		if tag == "n" then
			local j = s:find(";", i, true)
			local n = tonumber(s:sub(i, j - 1))
			i = j + 1
			return n
		elseif tag == "s" then
			local j = s:find(":", i, true)
			local len = tonumber(s:sub(i, j - 1))
			local v = s:sub(j + 1, j + len)
			i = j + len + 1
			return v
		elseif tag == "T" then return true
		elseif tag == "F" then return false
		elseif tag == "{" then
			local t = {}
			while s:sub(i, i) ~= "}" and i <= #s do
				local k = read()
				local v = read()
				t[tonumber(k) or k] = v
			end
			i = i + 1
			return t
		end
		return nil
	end
	local ok, v = pcall(read)
	return ok and v or nil
end

-- ===================================================================== 서버가 만든 글자 (프롬프트·간판)
-- 서버: 속성에 메시지를 넣고, 기본 글자는 영어로 채운다 (클라이언트가 번역하기 전)
function L.tag(obj, prop, msg)
	obj:SetAttribute("L_" .. prop, enc(msg))
	obj[prop] = text(msg, "en")
end

-- 클라이언트: 속성이 있는 물체의 글자를 내 언어로
function L.apply(obj)
	for name, value in pairs(obj:GetAttributes()) do
		if type(value) == "string" and name:sub(1, 2) == "L_" then
			local msg = L.decode(value)
			if msg ~= nil then pcall(function() obj[name:sub(3)] = text(msg) end) end
		end
	end
end

-- 클라이언트 자기 UI: 고정 글자를 키로 붙여 두면 언어가 바뀔 때 다시 채운다
local bound = setmetatable({}, {__mode = "k"})
function L.bind(obj, key, args, prop)
	prop = prop or "Text"
	bound[obj] = bound[obj] or {}
	bound[obj][prop] = {key, args}
	obj[prop] = L.t(key, args)
	return obj
end

local listeners = {}
function L.onChanged(fn) table.insert(listeners, fn) end

function L.set(code)
	code = tables[code] and code or "en"
	if code == L.lang then return end
	L.lang = code
	for obj, props in pairs(bound) do
		for prop, spec in pairs(props) do pcall(function() obj[prop] = L.t(spec[1], spec[2]) end) end
	end
	for _, fn in ipairs(listeners) do task.spawn(fn, code) end
end

-- 클라이언트: 작업 공간·내 화면의 번역 속성 달린 글자를 계속 번역
local watching = false
function L.watch(roots)
	if watching then return end
	watching = true
	local tagged = setmetatable({}, {__mode = "k"})
	local function consider(obj)
		if not (obj:IsA("GuiBase2d") or obj:IsA("ProximityPrompt") or obj:IsA("Tool")) then return end
		-- Roblox 자동 번역이 우리가 번역한 글자를 한 번 더 바꾸지 않게
		if not obj:IsA("Tool") then pcall(function() obj.AutoLocalize = false end) end
		local attrs = obj:GetAttributes()
		for name in pairs(attrs) do
			if name:sub(1, 2) == "L_" then
				if not tagged[obj] then
					tagged[obj] = true
					obj.AttributeChanged:Connect(function(attr) if attr:sub(1, 2) == "L_" then L.apply(obj) end end)
				end
				L.apply(obj)
				return
			end
		end
	end
	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do consider(obj) end
		root.DescendantAdded:Connect(function(obj) task.defer(consider, obj) end)
	end
	L.onChanged(function()
		for obj in pairs(tagged) do if obj.Parent then L.apply(obj) end end
	end)
end

return L
