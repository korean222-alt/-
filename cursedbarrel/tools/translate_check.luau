local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local root = require("@lune/process").cwd .. "/src/ReplicatedStorage/CursedBarrel/Shared/"
local dataFn = luau.load(fs.readFile(root .. "LocaleData.lua"), { debugName = "LocaleData" })
local DATA = dataFn()
local env = setmetatable({
	script = { Parent = { LocaleData = DATA } },
	require = function(x) return x end,
	typeof = typeof,
}, { __index = _G })
local Locale = luau.load(fs.readFile(root .. "Locale.lua"), { debugName = "Locale", environment = env })()
local input = fs.readFile(process.args[1])
for line in string.gmatch(input, "[^\n]+") do
	local out = Locale.translate(line)
	local mark = Locale.hasHangul(out) and "✗" or "✓"
	print(mark .. " " .. line .. "  =>  " .. out)
end
