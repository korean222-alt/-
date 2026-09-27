-- 한국어 문자열이 영어로 다 바뀌는지 검사한다 (진짜 Locale.translate · LocaleData 사용)
-- 사용 : python3 tools/extract_korean.py > ko.txt && lune run tools/check_locale.luau ko.txt
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local base = "src/ReplicatedStorage/CursedBarrel/Shared/"
local data = luau.load(fs.readFile(base .. "LocaleData.lua"), { debugName = "LocaleData" })()
local env = setmetatable({ script = { Parent = { LocaleData = "LocaleData" } }, require = function()
	return data
end, typeof = type }, { __index = _G })
for k, v in pairs(_G) do
	env[k] = v
end
env.require = function()
	return data
end
env.typeof = function(v)
	return type(v)
end
env.script = { Parent = { LocaleData = "LocaleData" } }
local Locale = luau.load(fs.readFile(base .. "Locale.lua"), { environment = env, debugName = "Locale" })()
local missing = 0
for line in string.gmatch(fs.readFile(process.args[1]) .. "\n", "(.-)\n") do
	local where, text = string.match(line, "^(.-)\t(.*)$")
	if text then
		text = string.gsub(text, "\\n", "\n")
		local out = Locale.translate(text)
		if string.find(out, "[\234-\237]") then
			missing += 1
			print(where .. "\t" .. string.gsub(text, "\n", "\\n") .. "\t=> " .. string.gsub(out, "\n", "\\n"))
		end
	end
end
print("번역 안 되는 문자열 : " .. missing)
